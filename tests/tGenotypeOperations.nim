import std/[random]

import nimgraphviz

import ../Genotype

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
assert mom.speciationDistance(dad) == (totalMutDiff / mom.links.len) * MUTDIFF_COEFF

# Crossover
## Clone
mom = newGenotype(2, 2)
child = mom.innovationCrossover(mom.clone())
for link in mom.links:
  echo link.repr
for link in child.links:
  echo link.repr
mom.toGraph.exportImage("mom.png")
child.toGraph.exportImage("child.png")
assert child.isClone(mom)
