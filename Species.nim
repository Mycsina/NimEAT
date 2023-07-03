import Genotype
import Operations

var COMPAT_THRESHOLD = 3.0

type
    Species* = ref object
        members*: seq[Genotype]
        representative*: Genotype
        topFitness*: float
        staleness*: int
        fitnessSum*: float

proc newSpecies*(representative: Genotype): Species =
    result.members = @[]
    result.representative = representative

proc addGenotype*(s: Species, g: Genotype) =
    s.members.add(g)

proc isCompatible*(s: Species, g: Genotype): bool =
    return g.speciationDistance(s.representative) < COMPAT_THRESHOLD
