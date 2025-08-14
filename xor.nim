import std/[math, jsonutils, json, random, os, posix, strformat]

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

param.setPopSize(512)

import nimgraphviz

randomize()

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
    
    let rawFitness = (4.0 - error)
    let complexityPenalty = 0.01 * o.genome.nodes.len.toFloat + 0.005 * o.genome.links.len.toFloat
    o.fitness = rawFitness - complexityPenalty
    
    return o.fitness > 3.79  # Adjusted threshold to account for penalty


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
        echo fmt"Input: {input} Expected: {outputs[i]} Actual: {res[0]}"

    echo "Fitness: ", champ.fitness
    echo "Nodes: ", champ.genome.nodes.len
    echo "Links: ", champ.genome.links.len

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
