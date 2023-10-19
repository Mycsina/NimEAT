import std/[random]

import ../../genotype
import ../../params

var mom, dad, child: Genotype

# Speciation Distance
## Clone
mom = newGenotype(2, 2)
assert mom.speciationDistance(mom.clone()) == 0.0
## Mutated weights
dad = newGenotype(2, 2)
### Assuming that the link mutation of all matching nodes ads up to 1
let totalMutDiff = 1
dad.links[1].mutDiff = 0.5
dad.links[2].mutDiff = 0.5
assert mom.speciationDistance(dad) == (totalMutDiff / mom.links.len) * param.MUTDIFF_COEFF
