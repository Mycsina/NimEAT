import std/[json, jsonutils, tables]

import genotype
import network
import species
import population

proc toJsonHook*(n: NodeGene): JsonNode =
    result = newJObject()
    result["id"] = toJson(n.id)
    result["type"] = toJson(n.nType)

proc toJsonHook*(l: LinkGene): JsonNode =
    result = newJObject()
    result["src"] = toJson(l.src)
    result["dst"] = toJson(l.dst)
    result["weight"] = toJson(l.weight)
    result["innovation"] = toJson(l.innovation)
    result["enabled"] = toJson(l.enabled)
    result["isRecurrent"] = toJson(l.isRecurrent)

proc toJsonHook*(g: Genotype): JsonNode =
    result = newJObject()
    result["nodes"] = newJArray()
    for n in g.nodes:
        result["nodes"].add(toJson(n))
    result["links"] = newJArray()
    for l in g.links:
        result["links"].add(toJson(l))
    result["inputs"] = toJson(g.inputs)
    result["outputs"] = toJson(g.outputs)
    result["fitness"] = toJson(g.fitness)
    result["species"] = toJson(g.species)

proc toJsonHook*(n: Node): JsonNode =
    result = newJObject()
    result["ntype"] = toJson(n.ntype)
    result["idx"] = toJson(n.id)
    result["value"] = toJson(n.value)
    result["activeSum"] = toJson(n.activeSum)
    result["gotInput"] = toJson(n.gotInput)
    result["activationCount"] = toJson(n.activationCount)
    result["lastValues"] = toJson(n.lastValues)
    result["ingoing"] = toJson(n.ingoing)

proc toJsonHook*(l: Link): JsonNode =
    result = newJObject()
    result["src"] = toJson(l.src)
    result["dst"] = toJson(l.dst)
    result["weight"] = toJson(l.weight)
    result["enabled"] = toJson(l.enabled)
    result["timeDelay"] = toJson(l.timeDelay)

proc toJsonHook*(n: Network): JsonNode =
    result = newJObject()
    result["nodes"] = newJArray()
    for node in n.nodes:
        result["nodes"].add(toJson(node))
    result["links"] = newJArray()
    for link in n.links:
        result["links"].add(toJson(link))
    result["inputs"] = newJArray()
    for node in n.inputs:
        result["inputs"].add(toJson(node))
    result["outputs"] = newJArray()
    for node in n.outputs:
        result["outputs"].add(toJson(node))
    result["score"] = toJson(n.score)
    result["blueprint"] = toJson(n.blueprint)

proc toJsonHook*(o: Organism): JsonNode =
    result = newJObject()
    result["id"].add(toJson(o.id))
    result["fitness"].add(toJson(o.fitness))
    result["originalFitness"].add(toJson(o.originalFitness))
    result["winner"].add(toJson(o.winner))
    result["net"].add(toJson(o.net))
    result["species"].add(toJson(o.species))
    result["genome"].add(toJson(o.genome))
    result["expectedOffspring"].add(toJson(o.expectedOffspring))
    result["generation"].add(toJson(o.generation))
    result["isLeader"].add(toJson(o.isLeader))
    result["isChampion"].add(toJson(o.isChampion))
    result["toDie"].add(toJson(o.toDie))

proc toJsonHook*(s: Species): JsonNode =
    result = newJObject()
    result["members"] = newJArray()
    for member in s.members:
        result["members"].add(toJson(member))
    result["representative"] = toJson(s.representative)
    result["topFitness"] = toJson(s.topFitness)
    result["bestEverFitness"] = toJson(s.bestEverFitness)
    result["averageFitness"] = toJson(s.averageFitness)
    result["expectedOffspring"] = toJson(s.expectedOffspring)
    result["age"] = toJson(s.age)
    result["ageLastImproved"] = toJson(s.ageLastImproved)
    result["averageEstimation"] = toJson(s.averageEstimation)
    result["extinct"] = toJson(s.extinct)
    result["novel"] = toJson(s.novel)

proc toJsonHook*(p: Population): JsonNode =
    result = newJObject()
    result["species"] = newJArray()
    for species in p.species:
        result["species"].add(toJson(species))
    result["meanFitness"] = toJson(p.meanFitness)
    result["variance"] = toJson(p.variance)
    result["stdDev"] = toJson(p.stdDev)
    result["winnerGen"] = toJson(p.winnerGen)
    result["highestFitness"] = toJson(p.highestFitness)
    result["ageSinceImprovement"] = toJson(p.ageSinceImprovement)
