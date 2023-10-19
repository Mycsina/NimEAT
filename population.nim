{.experimental: "codeReordering".}

import std/[algorithm, math, random, strformat, tables]

import genotype
import species
import params
import mutations

import utils

randomize()

type
    Population* = ref object
        currentGeneration*: int
        species*: OrderedTableRef[int, Species]
        population*: OrderedTableRef[int, Organism]
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
    result.species = newOrderedTable[int, Species]()
    result.population = newOrderedTable[int, Organism]()
    result.currentGeneration = 1

proc registerNewSpecies*(p: Population, representative: Organism) =
    ## Register a new species in the population
    let species = newSpecies(representative)
    species.id = SPECIES_HISTORY.len
    ## Add it to alive species
    p.species[species.id] = species
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
        p.population[o.id] = o
    for o in p.population.values:
        p.speciate(o)

proc speciate*(p: Population, o: Organism) =
    ## Assigns an organism to a species
    let speciesNum = SPECIES_HISTORY.len
    if speciesNum == 0:
        p.registerNewSpecies(o)
    else:
        # TODO closest species should be assigned and not first one
        for s in SPECIES_HISTORY:
            let distance = o.genome.speciationDistance(s.representative.genome)
            if distance < param.COMPAT_THRESHOLD:
                when defined(verbose):
                    echo "Organism ", o.id, " assigned to species ", s.id, " with distance ", distance
                s.addOrganism(o)
                return
        if o.species.isNil:
            when defined(verbose):
                echo "Organism ", o.id, " assigned to new species ", speciesNum + 1
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
        if param.COMPAT_THRESHOLD < param.COMPATIBILITY_MODIFIER:
            param.COMPAT_THRESHOLD = param.COMPATIBILITY_MODIFIER
    for s in p.species.values:
        s.sortMembers()
    ## Flag the lowest performing species
    p.sortSpecies(SortOrder.ASCENDING)
    for s in p.species.values:
        if s.age >= param.SPECIES_DROPOFF_AGE:
            if p.currentGeneration mod param.REGULAR_CULLING_INTERVAL == 0:
                s.extinct = true
                break
    p.sortSpecies()
    echo "Species: ", p.species.len
    when defined(verbose):
        echo "Compatibility threshold: ", param.COMPAT_THRESHOLD
    for s in p.species.values:
        s.adjustFitness()
        s.markForDeath()
    p.sortSpecies()
    p.expectedOffspring()
    let
        bestSpecies = p.species.getFirst()
        champion = bestSpecies.members.getFirst()
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
    # Mark old organisms for death
    for o in p.population.values:
        o.toDie = true
    for s in p.species.valuesSnapshot:
        # Print out species information
        #when defined(verbose):
        #    echo "Species ", s.id, ": age: ", s.age, " fitness: ", s.members[0].originalFitness, " size: ", s.members.len
        # If species is empty, delete it
        if s.members.len == 0:
            p.species.del(s.id)
        else:
            # Help new species
            if s.novel:
                s.novel = false
            else:
                s.age += 1
            for o in s.members.valuesSnapshot:
                # Remove old organisms from their species' list
                if o.toDie:
                    s.members.del(o.id)
                # Add new organisms to the population record
                else:
                    p.population[o.id] = o
            # Delete old organisms
            if s.members.len == 0:
                p.species.del(s.id)
    p.currentGeneration = newGen

proc expectedOffspring*(p: Population) =
    ## Rounds expected offspring and accurately carries the remainder across
    ## the whole population so that the children don't disappear
    when defined(verbose):
        echo "[Offspring]"
    let averageFit = p.averageFitness()
    var totalExpected = 0
    echo "Average fitness: ", averageFit
    for o in p.population.values:
        o.expectedOffspring = o.fitness / averageFit
    for s in p.species.values:
        var
            integer = 0
            fractional = 0.0
            expected = 0
            carry = 0.0
        for o in s.members.values:
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
            bestSpecies = p.species.getFirst()
        inc bestSpecies.expectedOffspring
        # If there does happen to be a problem, assign all
        # offspring to the best Species
        if totalExpected + 1 < p.population.len:
            for o in p.population.values:
                o.expectedOffspring = 0
            bestSpecies.expectedOffspring = p.population.len

proc deltaCoding*(p: Population) =
    ## Assign offspring to the leaders of the two best species
    when defined(verbose):
        echo "[Delta coding]"
    var
        bestSpecies: Species
        secondBest: Species
    p.sortSpecies()
    for s in p.species.values:
        if bestSpecies.isNil:
            bestSpecies = s
        else:
            secondBest = s
            break
    let
        halfPop = param.POP_SIZE / 2
        champion = bestSpecies.members.getFirst()
    p.ageSinceImprovement = 0
    ## Best organism gets half the population
    champion.expectedOffspring = halfPop
    bestSpecies.expectedOffspring = halfPop.toInt
    bestSpecies.ageLastImproved = bestSpecies.age
    ## Second best species leader gets the other half
    if not secondBest.isNil:
        secondBest.members[0].expectedOffspring = halfPop
        secondBest.expectedOffspring = halfPop.toInt
        secondBest.ageLastImproved = secondBest.age
        for s in p.species.values:
            if s != bestSpecies and s != secondBest:
                s.expectedOffspring = 0
    else:
        ## If there is only one species, assign all offspring to the champion
        champion.expectedOffspring += halfPop
        bestSpecies.expectedOffspring += halfPop.toInt

proc cullSpecies*(p: Population) =
    ## Cull all organisms that weren't chosen to reproduce
    ## FIXME: can this be optimized? It's 86.5% of the time spent in the algorithm
    when defined(verbose):
        echo "[Culling]"
    for o in p.population.valuesSnapshot:
        if o.toDie:
            o.species.members.del(o.id)
            p.population.del(o.id)
    for s in p.species.valuesSnapshot:
        if s.members.len == 0:
            p.species.del(s.id)

proc reproduce*(p: Population) =
    ## Reproduce all organisms marked for reproduction
    let values = p.species.valuesSnapshot
    for s in values:
        s.reproduce(p)

proc reproduce*(s: Species, p: Population) =
    ## Reproduces the species
    when defined(verbose):
        echo "[Reproduction] Species ", s.id, " reproducing"
    var
        keptLeader = false            ## Whether the leader has been kept
        leader = s.members.getFirst() ## The species leader
        baby: Organism                ## The baby to be created
    # If the species has no members, then it dies
    if s.expectedOffspring > 0 and s.members.len == 0:
        return
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
            when defined(verbose):
                echo "[Reproduction] Mutating champion ", leader.id
            baby = newOrganism(cloneGenome, 0.0, leader.generation + 1)
            leader.expectedOffspring -= 1
        elif not keptLeader and s.expectedOffspring > 5:
            ## If we still haven't saved the leader, do so
            var cloneGenome = leader.genome.clone()
            when defined(verbose):
                echo "[Reproduction] Saving species leader ", leader.id
            baby = newOrganism(cloneGenome, 0.0, leader.generation + 1)
            keptLeader = true
        elif rand(1.0) < param.MUT_ONLY_PROB or s.members.len == 1:
            ## If we choose to mutate/there's only us left
            var
                randomParent = s.members.getRand()
                cloneGenome = randomParent.genome.clone()
            mutate(cloneGenome)
            when defined(verbose):
                echo "[Reproduction] Mutating organism ", randomParent.id
            baby = newOrganism(cloneGenome, 0.0, randomParent.generation + 1)
        else:
            ## Otherwise, we should mate
            let mom = s.members.getRand()
            var dad: Organism
            ## Decide if we mate with our own species or another
            if rand(1.0) > param.INTERSPECIES_MATE_RATE:
                ## Mate within species
                when defined(verbose):
                    echo "[Reproduction] Mating organism ", mom.id, " within species"
                dad = s.members.getRand()
            else:
                ## Mate with other species
                var
                    randSpecies = s
                if not p.species.len == 1:
                    ## Try to find a species
                    while randSpecies == s:
                        ## Select random species, trending towards better species
                        var randmult = gaussRand() / 4.0
                        if randmult > 1.0:
                            randmult = 1.0
                        var randSpeciesIdx = floor(randmult * (p.species.len - 1).toFloat + 0.5).toInt
                        if randSpeciesIdx < 0:
                            randSpeciesIdx = p.species.len + randSpeciesIdx
                        randSpecies = p.species.getPosition(randSpeciesIdx)
                dad = randSpecies.members.getFirst()
                when defined(verbose):
                    echo fmt"[Reproduction] Mating organism {mom.id} from species {s.id} with organism {dad.id} from species {randSpecies.id}"
            var newGenome = mating(mom.genome, dad.genome)
            if rand(1.0) > param.MATE_ONLY_PROB:
                ## Randomly mutate the baby, or always if parents are the same.
                when defined(verbose):
                    echo "[Reproduction] Mutating mating result"
                mutate(newGenome)
            baby = newOrganism(newGenome, 0.0, p.currentGeneration + 1)
        ## Assign to species at birth
        p.speciate(baby)

proc speciesCmp*(a, b: (int, Species)): int =
    if a[1].members.getFirst().fitness > b[1].members.getFirst().fitness:
        return 1
    elif a[1].members.getFirst().fitness < b[1].members.getFirst().fitness:
        return -1
    else:
        return 0

proc sortSpecies*(p: Population, order = SortOrder.DESCENDING) =
    ## Sorts species in population by fittest organism
    p.species.sort(speciesCmp)

proc averageFitness*(p: Population): float =
    ## Returns the average fitness of the population
    var total = 0.0
    for o in p.population.values:
        total += o.fitness
    return total / p.population.len.toFloat
