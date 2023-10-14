{.experimental: "codeReordering".}

import std/[algorithm, math, random]

import Genotype
import Species
import Params
import Mutations

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
    result.species = @[]
    result.population = @[]
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

proc spawn*(p: Population, g: Genotype) =
    ## Spawns an initial population from a base genotype
    for i in 0 .. param.POP_SIZE:
        let g = g.clone()
        g.connect()
        g.mutateLinkWeights(1, 1, COLDGAUSSIAN)
        let o = newOrganism(g, 0.0, 1)
        p.population.add(o)
    for o in p.population:
        p.speciate(o)

proc speciate*(p: Population, o: Organism) =
    ## Assigns an organism to a species
    let speciesNum = SPECIES_HISTORY.len
    ## If there's no species, create one and register it
    if speciesNum == 0:
        p.registerNewSpecies(o)
    else:
        for s in SPECIES_HISTORY:
            let distance = o.genome.speciationDistance(s.representative.genome)
            if distance < param.COMPAT_THRESHOLD:
                s.addOrganism(o)
                return
        if o.species == nil:
            p.registerNewSpecies(o)


proc advanceGeneration*(p: Population) =
    ## Advances the population to the next generation
    let newGen = p.currentGeneration + 1
    echo "Generation ", p.currentGeneration
    echo "Population: ", p.population.len
    if param.ENFORCED_DIVERSITY:
        if p.species.len < param.DIVERSITY_TARGET:
            param.COMPAT_THRESHOLD -= param.COMPATIBILITY_MODIFIER
        elif p.species.len > param.DIVERSITY_TARGET:
            param.COMPAT_THRESHOLD += param.COMPATIBILITY_MODIFIER
        if param.COMPAT_THRESHOLD < 0.3:
            param.COMPAT_THRESHOLD = 0.3
    for s in p.species:
        s.sortMembers()
    p.sortSpecies()
    ## Flag the lowest performing species
    for i in countdown(p.species.high, 0):
        ## If age is above the threshold
        if p.species[i].age >= param.REGULAR_CULLING_AGE:
            ## If we're in the interval
            if p.currentGeneration mod param.REGULAR_CULLING_INTERVAL == 0:
                ## Mark for death
                p.species[i].extinct = true
                break
    echo "Species: ", p.species.len
    when defined(debug):
        echo "Compatibility threshold: ", param.COMPAT_THRESHOLD
    for s in p.species:
        echo "Species ", s.id, ": age: ", s.age, " fitness: ", s.members[0].fitness, " size: ", s.members.len
        s.adjustFitness()
        s.markForDeath()
    p.expectedOffspring()
    p.sortSpecies()
    let
        bestSpecies = p.species[0]
        champion = bestSpecies.members[0]
    ## Mark current champion
    champion.isChampion = true
    if champion.originalFitness > p.highestFitness:
        p.highestFitness = champion.originalFitness
        p.ageSinceImprovement = 0
        echo "New champion! Fitness: ", p.highestFitness
    else:
        p.ageSinceImprovement += 1
    if p.ageSinceImprovement >= 5 + param.DROPOFF_AGE:
        p.deltaCoding()
    elif param.BABIES_STOLEN > 0:
        ## TODO: implement baby stealing
        discard
    p.cullSpecies()
    p.sortSpecies()
    p.reproduce()
    # Empty population record and mark old organisms for death
    for o in p.population:
        o.toDie = true
    for sIdx in countdown(p.species.high, 0):
        let s = p.species[sIdx]
        # Print out species information
        #when defined(debug):
            #echo "Species ", s.id, ": age: ", s.age, " fitness: ", s.members[0].originalFitness, " size: ", s.members.len
        # If species is empty, delete it
        if s.members.len == 0:
            p.species.del(sIdx)
        else:
            # Help new species
            if s.novel:
                s.novel = false
            else:
                s.age += 1
            for oIdx in countdown(s.members.high, 0):
                let o = s.members[oIdx]
                # Remove old organisms from their species' list
                if o.toDie:
                    s.members.del(oIdx)
                    if s.members.len == 0:
                        p.species.del(sIdx)
                # Add new organisms to the population record
                else:
                    p.population.add(o)
    p.currentGeneration = newGen

proc expectedOffspring*(p: Population) =
    ## Rounds expected offspring and accurately carries the remainder across
    ## the whole population so that the children don't disappear
    let averageFit = p.averageFitness()
    var totalExpected = 0
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
    # Give any babies lost due to floating point errors to the
    # best Species
    if totalExpected < p.population.len:
        let
            bestSpecies = p.species[0]
        inc bestSpecies.expectedOffspring
        # If there does happen to be a problem, assign all
        # offspring to the best Species
        if totalExpected + 1 < p.population.len:
            for o in p.population:
                o.expectedOffspring = 0
            bestSpecies.expectedOffspring = p.population.len

proc deltaCoding*(p: Population) =
    ## Assign offspring to the leaders of the two best species
    let
        halfPop = param.POP_SIZE / 2
        bestSpecies = p.species[0]
        champion = bestSpecies.members[0]
    var
        secondBest: Species
    if len(p.species) > 1:
        secondBest = p.species[1]
    p.ageSinceImprovement = 0
    ## Best organism gets half the population
    champion.expectedOffspring = halfPop
    bestSpecies.expectedOffspring = halfPop.toInt
    bestSpecies.ageLastImproved = bestSpecies.age
    ## Second best species leader gets the other half
    if secondBest != nil:
        secondBest.members[0].expectedOffspring = halfPop
        secondBest.expectedOffspring = halfPop.toInt
        secondBest.ageLastImproved = secondBest.age
        for s in p.species:
            if s != bestSpecies and s != secondBest:
                s.expectedOffspring = 0
    else:
        ## If there is only one species, assign all offspring to the champion
        champion.expectedOffspring += halfPop
        bestSpecies.expectedOffspring += halfPop.toInt

proc cullSpecies*(p: Population) =
    ## Cull all organisms marked for death
    for i in countdown(p.population.high, 0):
        let o = p.population[i]
        if o.toDie:
            let pos = o.species.members.find(o)
            if pos == -1:
                echo o.id, " not found in species ", o.species.id
            o.species.members.del(pos)
            if o.species.members.len == 0:
                # We are sorting right after so we can do this safely
                p.species.del(p.species.find(o.species))
            p.population.del(i)

proc reproduce*(p: Population) =
    ## Reproduce all organisms marked for reproduction
    for i in 0..<p.species.len:
        p.species[i].reproduce(p)

proc reproduce*(s: Species, p: Population) =
    ## Reproduces the species
    var
        keptLeader = false    ## Whether the leader has been kept
        leader = s.members[0] ## The species leader
        baby: Organism        ## The baby to be created
    # If the species has no members, then it dies
    if s.expectedOffspring > 0 and s.members.len == 0:
        discard
    s.sortMembers()
    # Create the designed number of offspring for the Species
    for i in 0..<s.expectedOffspring:
        # If leader is population champion, mutate it
        if leader.isChampion and leader.expectedOffspring > 0:
            var cloneGenome = leader.genome.clone()
            if leader.expectedOffspring > 1:
                if rand(1.0) < 0.8 or param.MUT_ADD_LINK_PROB == 0.0:
                    cloneGenome.mutateLinkWeights(1.0, param.MUT_WEIGHT_POWER, GAUSSIAN)
                else:
                    cloneGenome.mutateAddLink()
            baby = newOrganism(cloneGenome, 0.0, leader.generation + 1)
            leader.expectedOffspring -= 1
        elif not keptLeader and s.expectedOffspring > 5:
            ## If we still haven't saved the leader, do so
            var cloneGenome = leader.genome.clone()
            baby = newOrganism(cloneGenome, 0.0, leader.generation + 1)
            keptLeader = true
        elif rand(1.0) < param.MUT_ONLY_PROB or s.members.len == 1:
            ## If we choose to mutate/there's only us left
            var
                randomParent = s.members[rand(s.members.high)]
                cloneGenome = randomParent.genome.clone()
                ## Check if structure was mutated
            mutate(cloneGenome)
            baby = newOrganism(cloneGenome, 0.0, randomParent.generation + 1)
        else:
            ## Otherwise, we should mate
            let mom = s.members[rand(s.members.high)]
            var dad: Organism
            ## Decide if we mate with our own species or another
            if rand(1.0) > param.INTERSPECIES_MATE_RATE:
                ## Mate within species
                dad = s.members[rand(s.members.high)]
            else:
                ## Mate with other species
                var
                    randSpecies = s
                if not p.species.len == 1:
                    ## Try to find a species
                    while randSpecies == s:
                        ## Select random species, trending towards better species
                        var randmult = gaussrand() / 4.0
                        if randmult > 1.0:
                            randmult = 1.0
                        let randSpeciesIdx = floor(randmult * p.species.high.toFloat + 0.5).toInt
                        ## Python-like negative indexing
                        if randSpeciesIdx < 0:
                            randSpecies = p.species[ ^ -randSpeciesIdx]
                        else:
                            randSpecies = p.species[randSpeciesIdx]
                dad = randSpecies.members[0]
            var newGenome = mating(mom.genome, dad.genome)
            if rand(1.0) > param.MATE_ONLY_PROB:
                ## Randomly mutate the baby, or always if parents are the same.
                mutate(newGenome)
            baby = newOrganism(newGenome, 0.0, p.currentGeneration + 1)
        ## Assign to species at birth
        p.speciate(baby)

proc speciesCmp*(a, b: Species): int =
    ## Species comparison function
    if a.members[0].originalFitness > b.members[0].originalFitness: return -1
    if a.members[0].originalFitness < b.members[0].originalFitness: return 1
    return 0

proc sortSpecies*(p: Population) =
    ## Sorts species in population by fittest organism
    ##
    ## Expects species' members to be sorted
    ## When run without -d:danger, it checks that the members are sorted
    for s in p.species:
        assert s.members.isSorted(organismCmp) == true
    p.species.sort(speciesCmp)

proc averageFitness*(p: Population): float =
    ## Returns the average fitness of the population
    var total = 0.0
    for o in p.population:
        total += o.fitness
    return total / p.population.len.toFloat
