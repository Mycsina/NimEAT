import std/[random, math]

import ../../genotype
import ../../params

var mom, dad, child: Genotype

# Speciation Distance
## Clone
mom = newGenotype(2, 2)
assert mom.speciationDistance(mom.clone()) == 0.0
## Mutated weights on two matching links summing to 1.0 difference
dad = mom.clone()
var delta1 = 0.5
var delta2 = 0.5
dad.links[1].weight = mom.links[1].weight + delta1
dad.links[2].weight = mom.links[2].weight + delta2
let expected = (abs(delta1) + abs(delta2)) / mom.links.len.toFloat * param.MUTDIFF_COEFF
assert abs(mom.speciationDistance(dad) - expected) < 1e-6
