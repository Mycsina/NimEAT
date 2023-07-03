import std/[algorithm]

import Genotype
import Operations

var
    COMPAT_THRESHOLD* = 3.0
    CURR_SPECIES* = 0

type
    Species* = ref object
        members*: seq[Genotype]
        representative*: Genotype
        topFitness*: float
        staleness*: int
        fitnessSum*: float

proc newSpecies*(representative: Genotype): Species =
    result = new Species
    result.members = @[]
    result.representative = representative
    inc CURR_SPECIES

proc addGenotype*(s: Species, g: Genotype) =
    s.members.add(g)

proc isCompatible*(s: Species, g: Genotype): bool =
    return g.speciationDistance(s.representative) < (COMPAT_THRESHOLD / (10 / CURR_SPECIES))

proc calculateFitnessSum(s: Species) =
    s.fitnessSum = 0.0
    for g in s.members:
        s.fitnessSum += g.fitness

proc averageFitness*(s: Species): float =
    s.calculateFitnessSum()
    return s.fitnessSum / s.members.len.toFloat

proc sortMembers*(s: Species) =
    s.members.sort(proc(a, b: Genotype): int =
        if a.fitness > b.fitness: return -1
        if a.fitness < b.fitness: return 1
        return 0)

proc removeWeakGenotypes*(s: Species, toKeep: int) =
    s.sortMembers()
    s.members = s.members[0..toKeep]

proc sharedFitness*(s: Species, g: Genotype) =
    g.adjustedFitness = s.fitnessSum / s.members.len.toFloat
