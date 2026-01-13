{.experimental: "codeReordering".}

import std/[algorithm, math, random, strformat]

import genotype
import species
import params
import mutations

randomize()

type
    Population* = ref object
        currentGeneration*: int
        species*: seq[Species]
        population*: seq[Organism]
        meanFitness*: float
        variance*: float
        stdDev*: float
        winnerGen*: int
        highestFitness*: float
        ageSinceImprovement*: int

var
    SPECIES_HISTORY: seq[Species]

proc newPopulation*(): Population =
    ## Creates a new population
    result = new(Population)
    result.species = newSeq[Species]()
    result.population = newSeq[Organism]()
    result.currentGeneration = 1

proc registerNewSpecies*(p: Population, representative: Organism) =
    ## Register a new species in the population
    let species = newSpecies(representative)
    species.id = SPECIES_HISTORY.len
    ## Add it to alive species
    p.species.add(species)
    ## Add it to species history
    if SPECIES_HISTORY.len > 0:
        if species notin SPECIES_HISTORY:
            SPECIES_HISTORY.add(species)
    else:
        SPECIES_HISTORY = @[species]
    when defined(verbose):
        echo "[Speciation] Organism ", representative.id, " assigned to new species ", species.id

proc spawn*(p: Population, g: Genotype) =
    ## Spawns an initial population from a base genotype
    for i in 0..<param.POP_SIZE:
        let g = g.clone()
        # Ensure initial genome has random weights
        g.mutateLinkWeights(1, 1, COLDGAUSSIAN)
        let o = newOrganism(g, 0.0, 1)
        p.population.add(o)
    for o in p.population:
        p.speciate(o)

proc advanceGeneration*(p: Population) =
    ## Advances the population to the next generation
    when defined(verbose):
        echo "Generation ", p.currentGeneration
        echo "Population: ", p.population.len
    if param.ENFORCED_DIVERSITY:
        param.adjustCompatibility(p)
    for s in p.species:
        s.sortMembers()
    ## Flag the lowest performing species
    p.sortSpecies(SortOrder.ASCENDING)
    for s in p.species:
        if s.age >= param.SPECIES_DROPOFF_AGE:
            if p.currentGeneration mod param.REGULAR_CULLING_INTERVAL == 0:
                s.extinct = true
                break
    p.sortSpecies()
    when defined(verbose):
        echo "Species: ", p.species.len
        echo "Compatibility threshold: ", param.COMPAT_THRESHOLD
    for s in p.species:
        s.adjustFitness()
        s.markForDeath()
    p.sortSpecies()
    p.expectedOffspring()
    let
        bestSpecies = p.species[0]
        champion = bestSpecies.members[0]
    ## Mark current champion
    champion.isChampion = true
    if champion.originalFitness > p.highestFitness:
        p.highestFitness = champion.originalFitness
        p.ageSinceImprovement = 0
        echo fmt"New champion! Fitness: {p.highestFitness} Generation: {p.currentGeneration}"
    else:
        p.ageSinceImprovement += 1
    ## If we have stagnated, delta code our population
    if p.ageSinceImprovement >= 5 + param.DROPOFF_AGE:
        p.deltaCoding()
    elif param.BABIES_STOLEN > 0:
        ## Baby Stealing: Take from worst, give to best
        let bestSpecies = p.species[0]
        var stolen = 0
        
        # Steal from worst species
        for i in countdown(p.species.high, 1): # Don't steal from best
            if stolen >= param.BABIES_STOLEN: break
            let s = p.species[i]
            while s.expectedOffspring > 0 and stolen < param.BABIES_STOLEN:
                dec s.expectedOffspring
                inc stolen
        
        # Give to best
        bestSpecies.expectedOffspring += stolen
    p.cullSpecies()
    p.sortSpecies()
    p.reproduce()
    # Remove old generation from population and species
    for oId in countdown(p.population.high, 0):
        let o = p.population[oId]
        o.species.members.del(o.species.members.find(o))
        when defined(verbose):
            echo fmt"Organism {o.id} removed from species {o.species.id} with size {o.species.members.len}"
        p.population.del(oId)
        when defined(verbose):
            echo fmt"Organism {o.id} removed from population with size {p.population.len}"
    # Remove all empty species, age surviving, create new generation
    for sId in countdown(p.species.high, 0):
        let s = p.species[sId]
        # If species is empty, delete it
        if s.members.len == 0:
            p.species.del(sId)
            when defined(verbose):
                echo fmt"Species {s.id} has been extinct"
        else:
            if s.novel:
                s.novel = false
            else:
                s.age += 1
            for oId in countdown(s.members.high, 0):
                let o = s.members[oId]
                p.population.add(o)
    inc p.currentGeneration

proc adjustCompatibility(params: NEATParams, p: Population) =
    ## Adjust the species compatibility threshold if not meeting diversity target
    if p.species.len < param.DIVERSITY_TARGET:
        param.COMPAT_THRESHOLD -= param.COMPATIBILITY_MODIFIER
    elif p.species.len > param.DIVERSITY_TARGET:
        param.COMPAT_THRESHOLD += param.COMPATIBILITY_MODIFIER
    if param.COMPAT_THRESHOLD < param.COMPATIBILITY_MODIFIER:
        param.COMPAT_THRESHOLD = param.COMPATIBILITY_MODIFIER

proc speciate*(p: Population, o: Organism) =
    ## Assigns an organism to the closest species based on genomic distance
    let speciesNum = SPECIES_HISTORY.len
    if speciesNum == 0:
        p.registerNewSpecies(o)
    else:
        var 
            bestSpecies: Species = nil
            minDist = high(float)
        
        # Find the closest compatible species
        for s in SPECIES_HISTORY:
            let dist = o.genome.speciationDistance(s.representative.genome)
            if dist < minDist:
                minDist = dist
                bestSpecies = s
        
        if not bestSpecies.isNil and minDist < param.COMPAT_THRESHOLD:
            when defined(verbose):
                echo fmt"[Speciation] Organism {o.id} assigned to species {bestSpecies.id} with distance {minDist}"
            bestSpecies.addOrganism(o)
            ## If species re-evolved into existence
            if bestSpecies notin p.species:
                when defined(verbose):
                    echo fmt"[Speciation] Species {bestSpecies.id} has revived."
                p.species.add(bestSpecies)
        else:
            p.registerNewSpecies(o)

proc expectedOffspring*(p: Population) =
    ## Rounds expected offspring and accurately carries the remainder across
    ## the whole population so that the children don't disappear
    when defined(verbose):
        echo "[Offspring]"
    let averageFit = p.averageFitness()
    var totalExpected = 0
    when defined(verbose):
        echo "Average fitness: ", averageFit
    for o in p.population:
        o.expectedOffspring = o.fitness / averageFit
    for s in p.species:
        var
            integer = 0
            fractional = 0.0
            expected = 0
            carry = 0.0
        for o in s.members:
            integer = toInt floor(o.expectedOffspring)
            fractional = o.expectedOffspring mod 1.0
            expected += integer
            carry += fractional
            if carry > 1.0:
                let entire = floor(carry).toInt
                expected += entire
                carry -= entire.toFloat
        s.expectedOffspring = expected
        totalExpected += expected
    
    # Baby Stealing / Gap Filling
    # Ensure total offspring exactly matches population size
    if totalExpected < p.population.len:
        # Give remaining slots to the best species
        let bestSpecies = p.species[0]
        bestSpecies.expectedOffspring += (p.population.len - totalExpected)
    elif totalExpected > p.population.len:
        # Steal slots from the worst species first
        var excess = totalExpected - p.population.len
        while excess > 0:
            for i in countdown(p.species.high, 0):
                if excess == 0: break
                if p.species[i].expectedOffspring > 0:
                    dec p.species[i].expectedOffspring
                    dec excess

proc deltaCoding*(p: Population) =
    ## Assign offspring to the leaders of the two best species
    when defined(verbose):
        echo "[Delta coding]"
    p.sortSpecies()
    var
        bestSpecies = p.species[0]
        secondBest: Species
        halfPop = p.population.len / 2
        champion = bestSpecies.members[0]
        secondLeader: Organism
    if p.species.len > 1:
        secondBest = p.species[1]
        secondLeader = secondBest.members[0]
    p.ageSinceImprovement = 0
    ## Best organism gets half the population
    champion.expectedOffspring = halfPop
    bestSpecies.expectedOffspring = halfPop.ceil.toInt
    bestSpecies.ageLastImproved = bestSpecies.age
    ## Second best species leader gets the other half
    if not secondBest.isNil:
        secondLeader.expectedOffspring = halfPop
        secondBest.expectedOffspring = halfPop.ceil.toInt
        secondBest.ageLastImproved = secondBest.age
        for s in p.species:
            if s != bestSpecies and s != secondBest:
                s.expectedOffspring = 0
    else:
        ## If there is only one species, assign all offspring to the champion
        champion.expectedOffspring += halfPop
        bestSpecies.expectedOffspring += halfPop.toInt

proc cullSpecies*(p: Population) =
    ## Cull all organisms that weren't chosen to reproduce
    when defined(verbose):
        echo "[Culling] Culling started"
    for oId in countdown(p.population.high, 0):
        let o = p.population[oId]
        if o.toDie:
            when defined(verbose):
                echo "[Culling] Removing organism " & $o.id
            o.species.members.del(o.species.members.find(o))
            p.population.del(oId)
    for sId in countdown(p.species.high, 0):
        let s = p.species[sId]
        if s.members.len == 0:
            p.species.del(sId)
    when defined(verbose):
        echo "[Culling] Culling finished"

proc reproduce*(p: Population) =
    ## Reproduce all organisms marked for reproduction
    when defined(verbose):
        echo "[Reproduction] Reproduction started"
    for i in 0..p.species.high:
        let s = p.species[i]
        var poolSize = s.members.high
        when defined(verbose):
            echo "[Reproduction] Species ", s.id, " reproducing"
        var
            keptLeader = false    ## Whether the leader has been kept
            leader = s.members[0] ## The species leader
            baby: Organism        ## The baby to be created
        # Using an assert so it gets optimized away when needed.
        assert not (s.expectedOffspring > 0 and s.members.len == 0)
        s.sortMembers()
        for _ in 0..<s.expectedOffspring:
            if leader.isChampion and leader.expectedOffspring > 0:
                when defined(verbose):
                    echo "[Reproduction] Mutating champion ", leader.id
                var cloneGenome = leader.genome.clone()
                if leader.expectedOffspring > 1:
                    cloneGenome.mutateChampionGenome()
                baby = newOrganism(cloneGenome, 0.0, leader.generation + 1)
                leader.expectedOffspring -= 1
            elif (not keptLeader) and s.expectedOffspring > 5:
                when defined(verbose):
                    echo "[Reproduction] Saving species leader ", leader.id
                var cloneGenome = leader.genome.clone()
                baby = newOrganism(cloneGenome, 0.0, leader.generation + 1)
                keptLeader = true
            elif rand(1.0) < param.MUT_ONLY_PROB or poolSize == 0:
                var
                    randomParent = s.members[rand(poolSize)]
                    cloneGenome = randomParent.genome.clone()
                when defined(verbose):
                    echo "[Reproduction] Mutating organism ", randomParent.id
                cloneGenome.mutate()
                baby = newOrganism(cloneGenome, 0.0, randomParent.generation + 1)
            else:
                let mom = s.members[rand(poolSize)]
                var dad: Organism
                if rand(1.0) > param.INTERSPECIES_MATE_RATE:
                    dad = s.members[rand(poolSize)]
                    when defined(verbose):
                        echo "[Reproduction] Mating organism ", mom.id, " within species"
                else:
                    let randSpecies = s.randOtherSpecies(p)
                    dad = randSpecies.members[0]
                    when defined(verbose):
                        echo fmt"[Reproduction] Mating organism {mom.id} from species {s.id} with organism {dad.id} from species {randSpecies.id}"
                var newGenome = mating(mom.genome, dad.genome)
                if rand(1.0) > param.MATE_ONLY_PROB or dad.genome == mom.genome:
                    when defined(verbose):
                        echo "[Reproduction] Mutating mating result"
                    newGenome.mutate()
                baby = newOrganism(newGenome, 0.0, p.currentGeneration + 1)
            p.speciate(baby)
        when defined(verbose):
            echo "[Reproduction] Reproduction complete"

proc mutateChampionGenome*(g: sink Genotype) =
    if rand(1.0) < 0.8 or param.MUT_ADD_LINK_PROB == 0.0:
        g.mutateLinkWeights(1.0, param.MUT_WEIGHT_POWER, GAUSSIAN)
    else:
        g.mutateAddLink()

proc randOtherSpecies(s: Species, p: Population): Species =
    ## Try to select a different species than the one provided, trending towards better ones
    var tries = 0
    var randSpecies = s
    if not p.species.len == 1:
        while randSpecies == s and tries < 5:
            var randmult = gaussRand() / 4.0
            if randmult > 1.0:
                randmult = 1.0
            var randSpeciesIdx = floor(randmult * (p.species.len - 1).toFloat + 0.5).toInt
            if randSpeciesIdx < 0:
                randSpeciesIdx = p.species.len + randSpeciesIdx
            randSpecies = p.species[randSpeciesIdx]
            inc tries
    return randSpecies

func speciesCmp*(a, b: Species): int =
    if a.members[0].fitness > b.members[0].fitness:
        return 1
    elif a.members[0].fitness < b.members[0].fitness:
        return -1
    else:
        return 0

proc sortSpecies*(p: Population, order = SortOrder.DESCENDING) =
    ## Sorts species in population by fittest organism
    p.species.sort(speciesCmp, order)

proc averageFitness*(p: Population): float =
    ## Returns the average fitness of the population
    var total = 0.0
    for o in p.population:
        total += o.fitness
    return total / p.population.len.toFloat
