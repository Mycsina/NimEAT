import std/[random, sets, macros]

import Genotype
import Params

proc mutateLinkWeights*(g: Genotype, chance: float, power: float, mutation: mutType) =
    let severe = rand(1.0) > 0.5
    var
        gaussPoint: float
        coldGaussPoint: float
        iter = 0
    for link in g.links:
        if rand(1.0) > 0.5:
            gaussPoint = 1.0 - chance
            coldGaussPoint = 1.0 - chance - 0.1
        else:
            gaussPoint = 1.0 - chance
            coldGaussPoint = 1.0 - chance
        # Shake more severely
        if severe:
            gaussPoint *= 1.5
            coldGaussPoint *= 1.5
        # Shake later links more
        if g.links.len >= 10 and iter > toInt (g.links.len.toFloat * 0.8):
            gaussPoint *= 2
            coldGaussPoint *= 2
        let randVal = randWeight() * power
        if mutation == GAUSSIAN:
            let choice = rand(1.0)
            if choice > gaussPoint:
                link.weight += randVal
            elif choice > coldGaussPoint:
                link.weight = randVal
        elif mutation == COLDGAUSSIAN:
            link.weight = randVal
        link.mutDiff = randVal
        iter += 1

macro checkLink(): untyped =
    quote do:
        var val = true
        for link in g.links:
            if link.src == node1 and link.dst == node2:
                val = false
                break
        if not val:
            inc tryCount
        else:
            # TODO: call network.isRecur here too
            var isRecursive = false
            if nGene1.nType == OUTPUT:
                isRecursive = true
            if not isRecursive:
                inc tryCount
            else:
                success = true
                break

proc mutateToggleEnable*(g: Genotype) =
    let randomGene = g.links[rand(g.links.high)]
    if randomGene.enabled:
        for i in 0..g.links.high:
            let gene = g.links[i]
            var val = true
            if gene.src == gene.src and gene.enabled == true and gene.innovation != randomGene.innovation:
                val = false
                break
            if val:
                randomGene.enabled = false
    else:
        randomGene.enabled = true

func mutateReenable*(g: Genotype) =
    for link in g.links:
        if not link.enabled:
            link.enabled = true

proc mutateAddNode*(g: Genotype) =
    var
        count = 0
        found = false
        randomGene = g.links[rand(g.links.high)]
    while count < 20 and not found:
        if randomGene.enabled or g.nodes[randomGene.src].nType != BIAS:
            found = true
        inc count
    if found:
        randomGene.enabled = false
        let
            oldWeight = randomGene.weight
        g.addNodeGene(HIDDEN, g.nodes.len)
        g.addLinkGene(randomGene.src, g.nodes[g.nodes.high].id, 1.0, true)
        g.addLinkGene(g.nodes[g.nodes.high].id, randomGene.dst, oldWeight, true)

proc mutateAddLink*(g: Genotype) =
    var
        tries = g.nodes.len * g.nodes.len
        tryCount = 0
        recursion = rand(1.0) > 0.5
        success = false
        # Found nodes
        node1 = 0
        node2 = 0
        nGene1: NodeGene
        nGene2: NodeGene
    if recursion:
        while tryCount < tries:
            # Decide if it's a recurrent loop or not
            if rand(1.0) > 0.5:
                node1 = rand(g.inputs..g.nodes.len - 1)
                node2 = node1
            else:
                node1 = rand(g.nodes.len - 1)
                node2 = rand(g.inputs..g.nodes.len - 1)
            nGene1 = g.nodes[node1]
            nGene2 = g.nodes[node2]
            # Check if link already exists
            checkLink()

    else:
        while tryCount < tries:
            node1 = rand(0..g.nodes.len - 1)
            node2 = rand(0..g.nodes.len - 1)
            nGene1 = g.nodes[node1]
            nGene2 = g.nodes[node2]
            # Check if link already exists
            checkLink()
    if success:
        g.addLinkGene(node1, node2, randWeight(), true)
        g.links[g.links.high].isRecurrent = recursion

proc structuralMutation*(g: Genotype): bool =
    ## Mutate the genome's structure
    var val = true
    if rand(1.0) < param.MUT_ADD_NODE_PROB:
        g.mutateAddNode()
        val = false
    elif rand(1.0) < param.MUT_ADD_LINK_PROB:
        g.mutateAddLink()
        val = false
    return val

proc connectionMutation*(g: Genotype) =
    ## Mutate the genome's connection weights
    if rand(1.0) < param.MUT_WEIGHT_PROB:
        g.mutateLinkWeights(1.0, param.MUT_WEIGHT_POWER, GAUSSIAN)
    if rand(1.0) < param.MUT_TOGGLE_PROB:
        g.mutateToggleEnable()
    if rand(1.0) < param.MUT_REENABLE_PROB:
        g.mutateReenable()

proc mutate*(g: Genotype) =
    ## Mutate either the genome's structure or its connection weights
    if not structuralMutation(g):
        connectionMutation(g)
