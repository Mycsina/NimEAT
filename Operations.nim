import std/[algorithm, random, sequtils, sets]

import Genotype

randomize()

var
    C1_COEFF* = 1.0
    C2_COEFF* = 1.0
    C3_COEFF* = 0.4

type
    Crossover* = concept x
        x(type Genotype, type Genotype) is Genotype
    Mutation* = concept x
        x.mutate(type Genotype) is Genotype
        x.chance is float
        x.chance > 0.0 and < 1.0

proc speciationDistance*(first, second: Genotype): float =
    let
        firstLinks = first.links
        secondLinks = second.links
        firstMax = max firstLinks.mapIt(it.innovation)
        secondMax = max secondLinks.mapIt(it.innovation)
        excessMark = max(firstMax, secondMax)
    var
        disjoint = 0
        excess = 0
        weight = 0.0
    # If first genotype has more links, it has any excess genes
    if excessMark == firstMax:
        for link in firstLinks:
            if link.innovation > secondMax:
                inc excess
            elif not (link in secondLinks):
                inc disjoint
            else:
                for findLink in secondLinks:
                    if findLink.innovation == link.innovation:
                        weight += abs(link.weight - findLink.weight)
                        break
    else:
        for link in secondLinks:
            if link.innovation > firstMax:
                excess += 1
            elif not (link in firstLinks):
                disjoint += 1
            else:
                for findLink in firstLinks:
                    if findLink.innovation == link.innovation:
                        weight += abs(link.weight - findLink.weight)
                        break
    return C1_COEFF * (excess / excessMark) + C2_COEFF * (disjoint / excessMark) + C3_COEFF * weight

type
    linkMutation* = object
        chance*: float
        mutate*: proc(x: Genotype): Genotype
    nodeMutation* = object
        chance*: float
        mutate*: proc(x: Genotype): Genotype

proc addLinkMutation*(genotype: Genotype): Genotype =
    var
        mutated = genotype.clone()
        tries = HashSet[(int, int)]()
        src: int
        dst: int
    while true:
        src = max(rand(mutated.nodes.len) - 1, genotype.inputIdx)
        dst = max(rand(mutated.nodes.len) - 1, genotype.hiddenIdx)
        if src == dst: continue
        if src > dst: swap(src, dst)
        if (src, dst) in tries: continue
        var val = true
        for link in mutated.links:
            if link.src == src and link.dst == dst:
                tries.incl((src, dst))
                val = false
                continue
        if val:
            break
    mutated.addLinkGene(src, dst, rand(1.0), true)
    return mutated

proc addNodeMutation*(genotype: Genotype): Genotype =
    var mutated = genotype.clone()
    var
        link = max(rand(mutated.links.len) - 1, 0)
        src = mutated.links[link].src
        dst = mutated.links[link].dst
    while src == dst or src == 0:
        link = max(rand(mutated.links.len) - 1, 0)
        src = mutated.links[link].src
        dst = mutated.links[link].dst
    mutated.links[link].enabled = false
    mutated.addNodeGene(HIDDEN)
    mutated.addLinkGene(src, mutated.nodes.len - 1, 1.0, true)
    mutated.addLinkGene(mutated.nodes.len - 1, dst, mutated.links[link].weight, true)
    return mutated

proc newLinkMutation*(chance: float, mutate: proc(x: Genotype): Genotype): Mutation =
    result = linkMutation(chance, mutate)

proc newLinkMutation*(chance: float): Mutation =
    result = newLinkMutation(chance, addLinkMutation)

proc newNodeMutation*(chance: float, mutate: proc(x: Genotype): Genotype): Mutation =
    result = nodeMutation(chance, mutate)

proc newNodeMutation*(chance: float): Mutation =
    result = nodeMutation(chance, addNodeMutation)

proc innovationCrossover*(first, second: Genotype): Genotype =
    let
        firstLinks = first.links
        secondLinks = second.links
        firstFitness = first.fitness
        secondFitness = second.fitness
        firstInnovation = firstLinks.mapIt(it.innovation)
        secondInnovation = secondLinks.mapIt(it.innovation)
    var child = newGenotype()
    for link in firstLinks:
        if link.innovation == 0:
            continue
        if link.innovation in secondInnovation:
            if rand(1.0) > 0.5:
                child.links.add(link)
            else:
                for findLink in secondLinks:
                    if findLink.innovation == link.innovation:
                        child.links.add(findLink)
                        break
        elif firstFitness > secondFitness:
            child.links.add(link)
    for link in secondLinks:
        if link.innovation == 0:
            continue
        if not (link.innovation in firstInnovation):
            child.links.add(link)
        elif secondFitness > firstFitness:
            child.links.add(link)
    child.sortInnovation()
    var uniqueSet = HashSet[int]()
    for link in child.links:
        uniqueSet.incl(link.src)
        uniqueSet.incl(link.dst)
    let firstNodes = first.nodes.mapIt(it.index)
    let secondNodes = second.nodes.mapIt(it.index)
    let uniqueNodes = uniqueSet.toSeq().sorted()
    for node in uniqueNodes:
        if node in firstNodes:
            child.addNodeGene(first.nodes[firstNodes[node]].nType)
        elif node in secondNodes:
            child.addNodeGene(second.nodes[secondNodes[node]].nType)
    return child
