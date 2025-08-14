import std/[algorithm, math, strformat]

import genotype
import network
import params

type
    Species* = ref object
        id*: int
        members*: seq[Organism]
        representative*: Organism
        leader*: Organism
        topFitness*: float
        bestEverFitness*: float
        averageFitness*: float
        expectedOffspring*: int
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

func `==`*(a, b: Species): bool =
    if not a.isNil and not b.isNil:
        return a.id == b.id
    return false

func `==`*(a, b: Organism): bool =
    if not a.isNil and not b.isNil:
        return a.id == b.id
    return false

var
    CURR_IND* = 0

proc addOrganism*(s: Species, o: Organism) =
    ## Add an organism to a species
    s.members.add(o)
    o.species = s

proc newSpecies*(representative: Organism): Species =
    result = new Species
    result.members = @[]
    result.representative = representative
    result.novel = true
    result.addOrganism(representative)

proc newSpecies*(representative: Organism, id: int): Species =
    result = newSpecies(representative)
    result.id = id

proc newOrganism*(g: Genotype, fit: float, gen: int): Organism =
    result = new Organism
    result.genome = g.clone()
    result.id = CURR_IND
    result.fitness = fit
    result.originalFitness = fit
    result.generation = gen
    # Build the network from the organism's own genome clone for determinism
    result.net = result.genome.generateNetwork()
    inc CURR_IND

proc recreate*(o: Organism) =
    o.net = o.genome.generateNetwork()

proc findChampion*(s: Species): Organism =
    var best: Organism = s.members[0]
    for g in s.members:
        if g.fitness > best.fitness:
            best = g
    return best

proc memberCmp*(a, b: Organism): int =
    ## Compare two organisms based on fitness
    if a.fitness > b.fitness:
        return 1
    elif a.fitness < b.fitness:
        return -1
    return 0

proc sortMembers*(s: Species, order = SortOrder.Descending) =
    ## Sort a species' members
    s.members.sort(memberCmp, order)
    s.leader = s.members[0]

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
    var parentNumber = toInt floor(param.SURVIVAL_THRESHOLD * s.members.len.toFloat + 1.0)
    when defined(verbose):
        echo fmt"[markForDeath] Available number of parent spots: {parentNumber}"
    # Elitism: always preserve the leader (best organism)
    for i, o in s.members:
        if i == 0 or parentNumber > 0:  # Leader is always at index 0 after sorting
            when defined(verbose):
                echo "Organism " & $o.id & " is going to be a parent."
            o.toDie = false
            if i > 0:  # Don't decrement for leader
                dec parentNumber
        else:
            o.toDie = true

proc calculateAvgFitness*(s: Species) =
    var total = 0.0
    for o in s.members:
        total += o.fitness
    s.averageFitness = total / s.members.len.toFloat

proc calculateMaxFitness*(s: Species) =
    s.sortMembers()
    s.topFitness = s.members[0].fitness

proc `$`*(s: Species): string =
    result = "Species ("
    result.add fmt"ID: {s.id}, "
    result.add fmt"Members: {s.members.len}, "
    result.add fmt"Representative: {s.representative.id})"
    result.add fmt"Age: {s.age}, "
    result.add fmt"AgeLastImproved: {s.ageLastImproved}, "
    result.add fmt"ExpectedOffspring: {s.expectedOffspring}, "
    result.add fmt"TopFitness: {s.topFitness}, "
    result.add fmt"BestEverFitness: {s.bestEverFitness}, "
    result.add fmt"AverageFitness: {s.averageFitness}, "
    result.add fmt"Novel: {s.novel}, "
