import std/[math, jsonutils, json, random, os]
import fusion/[ioutils]

when defined(debug):
    import nimprof
    let tmpFileName = "output.txt"
    let stdoutFileno = stdout.getFileHandle()
    let tmpFile = open(tmpFileName, fmWrite)
    let tmpFileFd = tmpFile.getFileHandle()
    duplicateTo(tmpFileFd, stdoutFileno)
    tmpFile.close()

import Genotype
import Network
import Population
import Species
import Params

param.setPopSize(512)
param.setEnforcedDiversity(false)
param.setAgeSignificance(3)

import nimgraphviz

randomize(2)

proc xorEvaluate(o: Organism): bool =
    let inputs = @[
        @[0.0, 0.0],
        @[0.0, 1.0],
        @[1.0, 0.0],
        @[1.0, 1.0]
    ]
    let outputs = @[
        0.0,
        1.0,
        1.0,
        0.0
    ]
    var error = 0.0
    for i in 0 ..< inputs.len:
        let res = o.net.predict(inputs[i])
        error += abs(res[0] - outputs[i])
    o.fitness = (4.0 - error).pow 2.0
    return o.fitness > 9.0

proc xorTest() =
    var g = newGenotype()
    g.addNodeGene(INPUT, 1)
    g.addNodeGene(INPUT, 2)
    g.addNodeGene(OUTPUT, 3)
    g.connect()
    let p = newPopulation()
    p.spawn(g)
    var
        winner = false
    while not winner:
        for o in p.population.values:
            if xorEvaluate(o):
                winner = true
                break
        p.advanceGeneration()
    echo "Winner found in generation ", p.currentGeneration
    p.population[0].net.blueprint.toGraph().exportImage("xor_winner.png")
    "xor_winner.json".open(fmWrite).write p.population[0].net.blueprint.toJson()

xorTest()
