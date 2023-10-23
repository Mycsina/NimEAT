import std/[math, jsonutils, json, random, os]
import fusion/[ioutils]

when defined(debug):
    import nimprof

when defined(log2file):
    let tmpFileName = "output.txt"
    let stdoutFileno = stdout.getFileHandle()
    let tmpFile = open(tmpFileName, fmWrite)
    let tmpFileFd = tmpFile.getFileHandle()
    duplicateTo(tmpFileFd, stdoutFileno)
    tmpFile.close()

import genotype
import network
import population
import species
import params

param.setPopSize(10)
param.setMutAddNodeProb(0.001)
param.setMutAddLinkProb(0.01)

import nimgraphviz

randomize(0)

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
    return o.fitness > 15.75


proc winnerTest(champ: Organism) =
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
    for i in 0..inputs.high:
        let input = inputs[i]
        let res = champ.net.predict(input)
        echo "Input: ", input
        echo "Expected: ", outputs[i]
        echo "Actual: ", res

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
        champion: Organism
    while not winner:
        for o in p.population:
            if xorEvaluate(o):
                winner = true
                champion = o
                break
        p.advanceGeneration()
    echo "Winner found in generation ", p.currentGeneration
    champion.net.blueprint.toGraph().exportImage("xor_winner.png")
    "xor_winner.json".open(fmWrite).write champion.net.blueprint.toJson()
    winnerTest(champion)

xorTest()
