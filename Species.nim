import std/[algorithm, math, random]

import Genotype
import Network
import Params

var
    CURR_IND* = 0
    CURR_SPECIES* = 0

type
    Species* = ref object
        id*: int
        members*: seq[Organism]
        representative*: Organism
        topFitness*: float
        bestEverFitness*: float
        averageFitness*: float
        expectedOffspring*: int
        parentNumber*: int
        age*: int
        ageLastImproved*: int
        averageEstimation*: float
        extinct*: bool
        novel*: bool
    Organism* = ref object
        id*: int
        fitness* = 0.0
        originalFitness* = 0.0
        winner*: bool
        net*: Network
        species*: Species
        genome*: Genotype
        expectedOffspring*: float
        generation*: int
        isLeader*: bool
        isChampion*: bool
        toDie*: bool
        # Optimization
        speciesPos*: int

proc addOrganism*(s: Species, o: Organism) =
    ## Add an organism to a species
    s.members.add(o)
    o.species = s
    o.speciesPos = s.members.high

proc newSpecies*(representative: Organism): Species =
    result = new Species
    result.members = @[]
    result.id = CURR_SPECIES
    result.representative = representative
    result.novel = true
    inc CURR_SPECIES

proc newSpecies*(representative: Organism, id: int): Species =
    result = new Species
    result.members = @[]
    result.id = id
    result.representative = representative
    result.novel = true
    inc CURR_SPECIES

proc newOrganism*(g: Genotype, fit: float, gen: int): Organism =
    result = new Organism
    result.genome = g.clone()
    result.id = CURR_IND
    result.fitness = fit
    result.originalFitness = fit
    result.generation = gen
    result.net = g.generateNetwork()
    inc CURR_IND

proc recreate*(o: Organism) =
    o.net = o.genome.generateNetwork()

proc findChampion*(s: Species): Organism =
    var champion: Organism
    champion.fitness = -1.0
    for g in s.members:
        if g.fitness > champion.fitness:
            champion = g
    return champion

proc organismCmp*(a, b: Organism): int =
    ## Organism comparison function
    if a.fitness > b.fitness: return -1
    if a.fitness < b.fitness: return 1
    return 0

proc sortMembers*(s: Species) =
    ## Sort a species' members
    s.members.sort(organismCmp)

proc adjustFitness*(s: Species) =
    ## Adjust fitness based on species age, sharing fitness amongst members.
    var ageDebt = s.age - s.ageLastImproved + 1 - param.DROPOFF_AGE
    if ageDebt == 0:
        ageDebt = 1
    for o in s.members:
        o.originalFitness = o.fitness
        # If the species is stagnated or is the worst one
        if ageDebt >= 1 or s.extinct:
            o.fitness *= 0.01
        # Boost young species
        if s.age <= 10:
            o.fitness *= param.AGE_SIGNIFICANCE
        # Fitness must be positive
        if o.fitness < 0.0:
            o.fitness = 0.0001
        # Share fitness with species
        o.fitness /= s.members.len.toFloat
    s.sortMembers()
    # Update ageLastImproved
    let mostFit = s.members[0]
    if mostFit.originalFitness > s.bestEverFitness:
        s.ageLastImproved = s.age
        s.bestEverFitness = mostFit.originalFitness
    mostFit.isLeader = true

proc markForDeath*(s: Species) =
    ## Marks organisms not able to be parents to die.
    s.parentNumber = toInt floor(param.SURVIVAL_THRESHOLD * s.members.len.toFloat + 1.0)
    for i in (s.parentNumber - 1)..s.members.high:
        s.members[i].toDie = true

proc structuralMutation*(g: Genotype): bool =
    ## Mutate the genome's structure
    var val = true
    if rand(1.0) < param.MUT_ADD_NODE_PROB:
        g.mutateAddNode()
        val = false
    elif rand(1.0) < param.MUT_ADD_LINK_PROB:
        g.mutateAddLink()
        val = false
    return val

proc connectionMutation*(g: Genotype) =
    ## Mutate the genome's connection weights
    if rand(1.0) < param.MUT_WEIGHT_PROB:
        g.mutateLinkWeights(1.0, param.MUT_WEIGHT_POWER, GAUSSIAN)
    if rand(1.0) < param.MUT_TOGGLE_PROB:
        g.mutateToggleEnable()
    if rand(1.0) < param.MUT_REENABLE_PROB:
        g.mutateReenable()

proc mutate*(g: Genotype) =
    ## Mutate either the genome's structure or its connection weights
    if not structuralMutation(g):
        connectionMutation(g)

proc calculateAvgFitness*(s: Species) =
    var total = 0.0
    for o in s.members:
        total += o.fitness
    s.averageFitness = total / s.members.len.toFloat

proc calculateMaxFitness*(s: Species) =
    s.sortMembers()
    s.topFitness = s.members[0].fitness

