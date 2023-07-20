import std/[algorithm, math, random]

import Genotype
import Network

var
    COMPAT_THRESHOLD* = 3.0
    CURR_SPECIES* = 0
    DROPOFF_AGE* = 15
    AGE_SIGNIFICANCE* = 1.0
    SURVIVAL_THRESHOLD* = 0.2
var
    INTERSPECIES_MATE_RATE* = 0.001
var
    MUT_ADD_LINK_PROB* = 0.05
    MUT_ADD_NODE_PROB* = 0.03
    MUT_WEIGHT_POWER* = 1.0
    MUT_WEIGHT_PROB* = 0.8
    MUT_ONLY_PROB* = 0.25
    MUT_TOGGLE_PROB* = 0.01
    MUT_REENABLE_PROB* = 0.00

type
    Species* = ref object
        id*: int
        members*: seq[Organism]
        representative*: Organism
        topFitness*: float
        historicalTopFitness*: float
        averageFitness*: float
        expectedOffspring*: int
        parentNumber*: int
        age*: int
        ageLastImproved*: int
        averageEstimation*: float
        extinct*: bool
        novel*: bool
    Organism* = ref object
        fitness*: float
        originalFitness*: float
        winner*: bool
        net*: Network
        species*: Species
        genome*: Genotype
        expectedOffspring*: float
        generation*: int
        isLeader*: bool
        isChampion*: bool
        toDie*: bool

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
    result.genome = g
    result.fitness = fit
    result.originalFitness = fit
    result.generation = gen
    result.net = g.generateNetwork()

proc recreate*(o: Organism) =
    o.net = o.genome.generateNetwork()

proc findChampion*(s: Species): Organism =
    var champion: Organism
    champion.fitness = -1.0
    for g in s.members:
        if g.fitness > champion.fitness:
            champion = g
    return champion

proc sortMembers*(s: Species) =
    s.members.sort(proc(a, b: Organism): int =
        if a.fitness > b.fitness: return -1
        if a.fitness < b.fitness: return 1
        return 0)

proc adjustFitness*(s: Species) =
    # Adjust fitness based on species age, sharing fitness amongst members
    var ageDebt = s.age - s.ageLastImproved + 1 - DROPOFF_AGE
    if ageDebt == 0:
        inc ageDebt
    for o in s.members:
        o.originalFitness = o.fitness
        if ageDebt >= 1:
            o.fitness *= 0.01
        if s.age <= 10:
            o.fitness *= AGE_SIGNIFICANCE
        if o.fitness < 0.0:
            o.fitness = 0.0001
        o.fitness /= s.members.len.toFloat
    s.sortMembers()
    let mostFit = s.members[0]
    if mostFit.fitness > s.historicalTopFitness:
        s.ageLastImproved = s.age
        s.historicalTopFitness = mostFit.originalFitness
    mostFit.isLeader = true

proc markForDeath*(s: Species) =
    # Mark underperforming organisms for death
    s.parentNumber = toInt floor(SURVIVAL_THRESHOLD * s.members.len.toFloat + 1.toFloat)
    for i in s.parentNumber..s.members.high:
        s.members[i].toDie = true

proc structuralMutation*(g: Genotype): bool =
    ## Mutate the genome's structure
    var val = true
    if rand(1.0) < MUT_ADD_NODE_PROB:
        g.mutateAddNode()
        val = false
    elif rand(1.0) < MUT_ADD_LINK_PROB:
        g.mutateAddLink()
        val = false
    return val

proc connectionMutation*(g: Genotype) =
    ## Mutate the genome's connection weights
    if rand(1.0) < MUT_WEIGHT_PROB:
        g.mutateLinkWeights(1.0, MUT_WEIGHT_POWER, GAUSSIAN)
    if rand(1.0) < MUT_TOGGLE_PROB:
        g.mutateToggleEnable()
    if rand(1.0) < MUT_REENABLE_PROB:
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

