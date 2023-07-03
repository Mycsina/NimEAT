import Genotype
import Population
import Phenotype
import Operations

import nimgraphviz

let p = initialize()

proc xor_fitness*(phe: Phenotype): float =
    var tests = [(0, 0, 0), (0, 1, 1), (1, 0, 1), (1, 1, 0)]
    var fitness = 0.0
    for (a, b, c) in tests:
        var output = phe.getOutputs(@[a.toFloat, b.toFloat])
        fitness += 1.0 - abs(output[0] - c.toFloat)
    return fitness

proc goal*(x: float): bool =
    return x > 3.5

p.run(xor_fitness, goal)
