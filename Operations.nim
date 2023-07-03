import std/[random, sequtils]

import Genotype

randomize()

var
    C1_COEFF* = 1.0
    C2_COEFF* = 1.0
    C3_COEFF* = 0.4

type
    Crossover = concept x
        x(type Genotype, type Genotype) is Genotype
    Mutation = concept x
        x(type Genotype) is Genotype

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

proc addLinkMutation*(genotype: Genotype): Genotype =
    var mutated = deepCopy genotype
    while true:
        let
            input = rand(mutated.nodes.len)
            output = rand(mutated.nodes.len)
        if input == output:
            continue
        var src, dst: int
        for link in mutated.links:
            src = link.src
            dst = link.dst
            if link.src == input and link.dst == output:
                break
        if src == input and dst == output:
            continue
        mutated.addLinkGene(input, output, rand(1.0), true)
        return mutated

proc addNodeMutation*(genotype: Genotype): Genotype =
    var mutated = deepCopy genotype
    let
        link = rand(mutated.links.len)
        src = mutated.links[link].src
        dst = mutated.links[link].dst
    mutated.links[link].enabled = false
    mutated.addNodeGene(OUTPUT)
    mutated.addLinkGene(src, mutated.nodes.len - 1, 1.0, true)
    mutated.addLinkGene(mutated.nodes.len - 1, dst, mutated.links[link].weight, true)
    return mutated

proc innovationCrossover*(first, second: Genotype): Genotype =
    let
        firstLinks = deepCopy first.links
        secondLinks = deepCopy second.links
    #    firstMax = max firstLinks.mapIt(it.innovation)
    #    secondMax = max secondLinks.mapIt(it.innovation)
    var child = newGenotype()
    for link in firstLinks:
        if link in secondLinks:
            if rand(1.0) > 0.5:
                child.links.add(link)
            else:
                for findLink in secondLinks:
                    if findLink.innovation == link.innovation:
                        child.links.add(findLink)
                        break
        else:
            child.links.add(link)
    for link in secondLinks:
        if not (link in firstLinks):
            child.links.add(link)
    child.sortInnovation()
    return child

proc innovationCrossover*(first, second: Genotype, fitness: proc(x: Genotype): int): Genotype =
    let
        firstLinks = deepCopy first.links
        secondLinks = deepCopy second.links
    #    firstMax = max firstLinks.mapIt(it.innovation)
    #    secondMax = max secondLinks.mapIt(it.innovation)
        firstFitness = first.fitness
        secondFitness = second.fitness
    var child = newGenotype()
    for link in firstLinks:
        if link in secondLinks:
            if rand(1.0) > 0.5:
                child.links.add(link)
            else:
                for findLink in secondLinks:
                    if findLink.innovation == link.innovation:
                        child.links.add(findLink)
                        break
        # Add disjoint and excess genes
        elif firstFitness > secondFitness:
            child.links.add(link)
    # Add disjoint and excess genes
    if secondFitness > firstFitness:
        for link in secondLinks:
            if not (link in firstLinks):
                child.links.add(link)
    child.sortInnovation()
    return child
