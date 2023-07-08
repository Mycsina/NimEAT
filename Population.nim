{.experimental: "codeReordering".}

import std/[algorithm, math, random]

import Genotype
import Species

randomize()

var
    POP_SIZE* = 256
var
    REGULAR_CULLING_AGE* = 15
    REGULAR_CULLING_INTERVAL* = 30
var
    ENFORCED_DIVERSITY* = true
    DIVERSITY_TARGET* = 5
    COMPAT_THRESHOLD* = 3.0
    COMPATIBILITY_MODIFIER* = 0.3
var
    BABIES_STOLEN* = 0
    MATE_ONLY_PROB* = 0.2

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
        ageSinceLastImprovement*: int


proc newPopulation*(): Population =
    result = new(Population)
    result.species = @[]
    result.population = @[]

proc spawn*(p: Population, g: Genotype) =
    ## Spawns an initial population from a base genotype
    for i in 0 .. POP_SIZE:
        let g = g.clone()
        g.connect()
        g.mutateLinkWeights(1, 1, COLDGAUSSIAN)
        let o = newOrganism(g, 0.0, 1)
        p.population.add(o)
    p.speciate()

proc speciate*(p: Population) =
    ## Assigns each organism to a species
    for o in p.population:
        let speciesNum = p.species.len
        if speciesNum == 0:
            let species = newSpecies(o, speciesNum + 1)
            p.species.add(species)
            o.species = species
        else:
            for s in p.species:
                if o.genome.speciationDistance(s.representative.genome) < COMPAT_THRESHOLD:
                    o.species = s
                    s.members.add(o)
                    break
            if o.species == nil:
                let species = newSpecies(o, speciesNum + 1)
                p.species.add(species)
                o.species = species

proc advanceGeneration*(p: Population) =
    ## Advances the population to the next generation
    let newGen = p.currentGeneration + 1
    echo "Generation ", newGen
    if ENFORCED_DIVERSITY:
        if p.species.len < DIVERSITY_TARGET:
            COMPAT_THRESHOLD -= COMPATIBILITY_MODIFIER
        elif p.species.len > DIVERSITY_TARGET:
            COMPAT_THRESHOLD += COMPATIBILITY_MODIFIER
        if COMPAT_THRESHOLD < 0.3:
            COMPAT_THRESHOLD = 0.3
    for s in p.species:
        s.sortMembers()
    p.sortSpecies()
    ## Eliminates old, low performing species every x generations
    ## Expects species to be sorted
    for i in countdown(p.species.len - 1, 0):
        if p.species[i].age >= REGULAR_CULLING_AGE:
            if p.currentGeneration mod REGULAR_CULLING_INTERVAL == 0:
                p.species[i].extinct = true
    echo "Species: ", p.species.len
    echo "Compatibility threshold: ", COMPAT_THRESHOLD
    for s in p.species:
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
        p.ageSinceLastImprovement = 0
        echo "New champion! Fitness: ", p.highestFitness
    else:
        p.ageSinceLastImprovement += 1
    if p.ageSinceLastImprovement >= 5 + DROPOFF_AGE:
        p.deltaCoding()
    elif BABIES_STOLEN > 0:
        ## TODO: implement baby stealing
        discard
    p.cullSpecies()
    p.reproduce()
    # Remove organisms from their species' list and from the master record
    for i in countdown(p.population.len - 1, 0):
        let o = p.population[i]
        o.species.members.remove(o)
        p.population.remove(o)
    for s in p.species:
        if s.members.len == 0:
            p.species.remove(s)
        else:
            if s.novel:
                s.novel = false
            else:
                s.age += 1
            for o in s.members:
                p.population.add(o)
    p.currentGeneration = newGen


proc expectedOffspring*(p: Population) =
    ## Calculates expected offspring for each organism, and then per Species
    let averageFit = p.averageFitness()
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
            integer = floor(o.expectedOffspring).toInt
            fractional = o.expectedOffspring mod 1.0
            expected += integer
            carry += fractional
            if carry > 1.0:
                let entire = floor(carry).toInt
                expected += entire
                carry -= entire.toFloat
    # TODO: we may need to be more precise due to rounding errors

proc deltaCoding*(p: Population) =
    ## Assign offspring to the leaders of the two best species
    let
        halfPop = POP_SIZE / 2
        bestSpecies = p.species[0]
        champion = bestSpecies.members[0]
    var
        secondBest: Species
    if len(p.species) > 1:
        secondBest = p.species[1]
    p.ageSinceLastImprovement = 0
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
            o.species.members.remove(o)
            p.population.remove(o)

proc reproduce*(p: Population) =
    ## Reproduce all organisms marked for reproduction
    for s in p.species:
        s.reproduce(p)

proc reproduce*(s: Species, p: Population) =
    ## Reproduces the species
    var
        keptLeader = false ## Whether the leader has been kept
        baby: Organism     ## The baby to be created
    # If the species has no members, then it dies
    if s.expectedOffspring > 0 and s.members.len == 0:
        discard
    s.sortMembers()
    # Create the designed number of offspring for the Species
    for i in 0..<s.expectedOffspring:
        let leader = s.members[0]
        # If leader is population champion, mutate it
        if leader.isChampion:
            let cloneGenome = leader.genome.clone()
            if leader.expectedOffspring > 1:
                if rand(1.0) < 0.8 or MUT_ADD_LINK_PROB == 0.0:
                    cloneGenome.mutateLinkWeights(1.0, MUT_WEIGHT_POWER, GAUSSIAN)
                else:
                    cloneGenome.mutateAddLink()
            baby = newOrganism(cloneGenome, 0.0, leader.generation + 1)
            leader.expectedOffspring -= 1
        elif not keptLeader and s.expectedOffspring > 5:
            ## If we still haven't saved the leader, do so
            let cloneGenome = leader.genome.clone()
            baby = newOrganism(cloneGenome, 0.0, leader.generation + 1)
            keptLeader = true
        elif rand(1.0) < MUT_ONLY_PROB or s.members.len == 1:
            ## If we choose to mutate/there's only us left
            let
                randomParent = s.members[rand(s.members.high)]
                cloneGenome = randomParent.genome.clone()
                ## Check if structure was mutated
            mutate(s, cloneGenome)
            baby = newOrganism(cloneGenome, 0.0, randomParent.generation + 1)
        else:
            ## Otherwise, we should mate
            let
                mom = s.members[rand(s.members.high)]
            var dad: Organism
            ## Decide if we mate with our own species or another
            if rand(1.0) > INTERSPECIES_MATE_RATE:
                ## Mate within species
                dad = s.members[rand(s.members.high)]
            else:
                ## Mate with other species
                var
                    randSpecies = s
                    tries = 0
                ## Try to find a species
                while randSpecies == s and tries < 5:
                    randSpecies = p.species[rand(p.species.high)]
                    tries += 1
                    ## Select random species, trending towards better species
                    var randmult = gaussrand() / 4.0
                    if randmult > 1.0:
                        randmult = 1.0
                    let randSpeciesIdx = floor(randmult * randSpecies.members.high.toFloat + 0.5).toInt
                    randSpecies = p.species[randSpeciesIdx]
                dad = randSpecies.members[0]
            let newGenome = mating(mom.genome, dad.genome)
            if rand(1.0) > MATE_ONLY_PROB or dad.genome == mom.genome or dad.genome.speciationDistance(mom.genome) == 0.0:
                ## Randomly mutate the baby, or always if parents are the same.
                mutate(s, newGenome)
            baby = newOrganism(newGenome, 0.0, p.currentGeneration + 1)
        p.population.add(baby)
    p.speciate()

proc sortSpecies*(p: Population) =
    p.species.sort(proc(a, b: Species): int =
        if a.members[0].originalFitness > b.members[0].originalFitness: return -1
        if a.members[0].originalFitness < b.members[0].originalFitness: return 1
        return 0)

proc averageFitness*(p: Population): float =
    var total = 0.0
    for o in p.population:
        total += o.fitness
    return total / p.population.len.toFloat
