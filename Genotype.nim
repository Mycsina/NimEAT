{.experimental: "codeReordering".}

import std/[algorithm, tables, random, sequtils, sets, macros]

import nimgraphviz

randomize()

var
    DISJOINT_COEFF* = 1.0
    EXCESS_COEFF* = 1.0
    MUTDIFF_COEFF* = 0.4
var
    MATE_MULTIPOINT_PROB* = 1.0
    DISABLED_GENE_INHERIT_PROB* = 0.75


type
    NType* = enum
        INPUT, HIDDEN, OUTPUT, BIAS
    NodeGene* = ref object
        id*: int
        nType*: NType
    LinkGene* = ref object
        src*: int
        dst*: int
        weight*: float
        innovation*: int
        enabled*: bool
        isRecurrent*: bool
    # store output nodes separately so we can regularly iterate over nodes
    Genotype* = ref object
        nodes*: seq[NodeGene]
        links*: seq[LinkGene]
        inputs*: int
        outputs*: int
        fitness*: float
        species*: int

var
    INNO_CONST* = 1
    SEEN_INNO* = newTable[(int, int), int]()

proc resetInnovation*() =
    INNO_CONST = 1
    SEEN_INNO = newTable[(int, int), int]()

proc newNodeGene*(nodeType: NType, id: int): NodeGene =
    result = new NodeGene
    result.nType = nodeType
    result.id = id

proc newLinkGene*(src: int, dst: int, weight: float, enabled: bool): LinkGene =
    result = new LinkGene
    result.src = src
    result.dst = dst
    result.weight = weight
    result.enabled = enabled
    if src != 0:
        if SEEN_INNO.hasKey((src, dst)):
            result.innovation = SEEN_INNO[(src, dst)]
        else:
            result.innovation = INNO_CONST
            SEEN_INNO[(src, dst)] = INNO_CONST
            inc INNO_CONST

proc newGenotype*(): Genotype =
    result = new Genotype
    result.nodes = @[]
    result.links = @[]
    result.addNodeGene(BIAS, 0)

proc addNodeGene*(this: Genotype, nodeType: NType, id: int) =
    let
        v = newNodeGene(nodeType, id)
    this.nodes.add(v)
    if nodeType == INPUT:
        inc this.inputs
    elif nodeType == OUTPUT:
        inc this.outputs
    # Connect to bias node if not input
    if (nodeType != INPUT and nodeType != BIAS):
        discard this.addLinkGene(0, id, 1.0, true)

proc addLinkGene*(this: Genotype, src: int, dst: int, weight: float, enabled: bool): LinkGene =
    let l = newLinkGene(src, dst, weight, enabled)
    this.links.add(l)
    return l

proc addLinkGene*(this: Genotype, src: int, dst: int, weight: float, enabled: bool, innovation: int): LinkGene =
    var l = newLinkGene(src, dst, weight, enabled)
    l.innovation = innovation
    this.links.add(l)
    return l

proc clone*(this: Genotype): Genotype =
    result = newGenotype()
    for n in this.nodes:
        if n.nType != NType.BIAS:
            result.addNodeGene(n.nType, n.id)
    for l in this.links:
        if l.src != 0:
            discard result.addLinkGene(l.src, l.dst, l.weight, l.enabled, l.innovation)

proc clone*(this: LinkGene): LinkGene =
    result = newLinkGene(this.src, this.dst, this.weight, this.enabled)
    result.innovation = this.innovation

proc checkNode*(this: Genotype, id: int): bool =
    for n in this.nodes:
        if n.id == id:
            return true
    return false

proc sortNodes*(this: Genotype) =
    this.nodes.sort(proc(a, b: NodeGene): int = a.id - b.id)

proc sortInnovation*(this: Genotype) =
    this.links.sort(proc(a, b: LinkGene): int = a.innovation - b.innovation)

proc sortTopology*(this: Genotype) =
    this.sortNodes()
    this.sortInnovation()

proc toGraph*(this: Genotype): Graph[Edge] =
    var graph = newGraph[Edge]()
    for link in this.links:
        if link.enabled:
            graph.addEdge($link.src -- $link.dst)
    return graph

## Operations

type
    mutType* = enum
        GAUSSIAN, COLDGAUSSIAN

proc randomSignal*(): int =
    # Randomly return 1 or -1
    if rand(1.0) > 0.5:
        return 1
    else:
        return -1

proc randWeight*(): float =
    # Randomly return a weight between -1 and 1
    return rand(1.0) * randomSignal().toFloat

proc gaussRand*(): float =
    ## Returns a normally distributed deviate with 0 mean and unit variance
    return gauss(0.0, 1.0)

proc connect*(this: Genotype) =
    ## Connect all input nodes to all output nodes
    for i in 1..this.inputs:
        for j in this.inputs+1..this.inputs+this.outputs:
            discard this.addLinkGene(i, j, randWeight(), true)

proc remove*[T](container: var seq[T], item: T) =
    # Remove an item from a sequence
    var idx = container.find(item)
    if idx != -1:
        container.delete(idx)

proc speciationDistance*(first, second: Genotype): float =
    var
        numDisjoint = 0.0
        numExcess = 0.0
        numMatching = 0.0
    let
        size1 = first.links.len
        size2 = second.links.len
        maxGenomeSize = max(size1, size2)
    var
        gene1, gene2: LinkGene
        i, i1, i2: int = 0
    while i < maxGenomeSize:
        if i1 >= size1:
            numExcess += 1.0
            i2 += 1
        elif i2 >= size2:
            numExcess += 1.0
            i1 += 1
        else:
            gene1 = first.links[i1]
            gene2 = second.links[i2]
            let
                p1innov = gene1.innovation
                p2innov = gene2.innovation
            if p1innov == p2innov:
                numMatching += 1.0
                i1 += 1
                i2 += 1
            elif p1innov < p2innov:
                i1 += 1
                numDisjoint += 1.0
            elif p2innov < p1innov:
                i2 += 1
                numDisjoint += 1.0
        inc i
    result = DISJOINT_COEFF * numDisjoint + EXCESS_COEFF * numExcess + MUTDIFF_COEFF * (numMatching /
            maxGenomeSize.toFloat)

proc mutateLinkWeights*(g: Genotype, chance: float, power: float, mutation: mutType) =
    let severe = rand(1.0) > 0.5
    var
        gaussPoint: float
        coldGaussPoint: float
        iter: int
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
        let
            randVal = randWeight() * power
        if mutation == GAUSSIAN:
            let choice = rand(1.0)
            if choice > gaussPoint:
                link.weight += randVal
            elif choice > coldGaussPoint:
                link.weight = randVal
        elif mutation == COLDGAUSSIAN:
            link.weight = randVal
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
            var val: bool
            if gene.src == gene.src and gene.enabled == true and gene.innovation != randomGene.innovation:
                val = false
                break
            if val:
                randomGene.enabled = false
    else:
        randomGene.enabled = true

proc mutateReenable*(g: Genotype) =
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
        discard g.addLinkGene(randomGene.src, g.nodes[g.nodes.high].id, 1.0, true)
        discard g.addLinkGene(g.nodes[g.nodes.high].id, randomGene.dst, oldWeight, true)

proc mutateAddLink*(g: Genotype) =
    var
        tries = g.nodes.len * g.nodes.len
        tryCount = 0
        recursion = rand(1.0) > 0.5
        success = false
        # Found nodes
        node1: int
        node2: int
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
        let l = g.addLinkGene(node1, node2, randWeight(), true)
        l.isRecurrent = recursion

proc innovationCrossover(first, second: Genotype): Genotype =
    let
        fitness1 = first.fitness
        fitness2 = second.fitness
        child = newGenotype()
    var
        better1: bool
    ## Determine which genome is better
    if fitness1 > fitness2:
        better1 = true
    elif fitness1 == fitness2:
        ## Smaller with same fitness is better
        better1 = first.links.len < second.links.len
    else:
        better1 = false
    ## Add inputs, outputs, and bias to child
    for node in second.nodes:
        if node.nType in [INPUT, BIAS, OUTPUT]:
            child.addNodeGene(node.nType, node.id)
    var
        fIter, sIter = 0
        skip: bool
        chosenLink: LinkGene
    while not (fIter == first.links.high and sIter == second.links.high):
        skip = false
        if fIter == first.links.high:
            ## Reached end of first genome
            chosenLink = second.links[sIter].clone()
            inc sIter
            if better1: skip = true
        elif sIter == second.links.high:
            ## Reached end of second genome
            chosenLink = first.links[fIter].clone()
            inc fIter
            if not better1: skip = true
        else:
            let
                fInnov = first.links[fIter].innovation
                sInnov = second.links[sIter].innovation
            if fInnov == sInnov:
                ## If same innovation number, randomly choose one
                if rand(1.0) > 0.5:
                    chosenLink = first.links[fIter].clone()
                else:
                    chosenLink = second.links[sIter].clone()
                if first.links[fIter].enabled == false or second.links[sIter].enabled == false:
                    if rand(1.0) < DISABLED_GENE_INHERIT_PROB:
                        child.links[child.links.high].enabled = false
                inc fIter
                inc sIter
            elif fInnov < sInnov:
                ## If first innovation is smaller, choose it
                chosenLink = first.links[fIter].clone()
                inc fIter
                if not better1: skip = true
            elif fInnov > sInnov:
                chosenLink = second.links[sIter].clone()
                inc sIter
                if better1: skip = true
        ## Chose a link, check if it already exists
        var val = true
        for link in child.links:
            if link.src == chosenLink.src and link.dst == chosenLink.dst:
                val = false
                break
        if not val:
            skip = true
        if not skip:
            # check if child has node genes for the link
            let
                inNode = chosenLink.src
                outNode = chosenLink.dst
            if not child.checkNode(inNode):
                child.addNodeGene(HIDDEN, inNode)
            if not child.checkNode(outNode):
                child.addNodeGene(HIDDEN, outNode)
            discard child.addLinkGene(inNode, outNode, chosenLink.weight, chosenLink.enabled)
    return child

proc singlepointCrossover(first, second: Genotype): Genotype =
    discard

proc mating*(first, second: Genotype): Genotype =
    if rand(1.0) < MATE_MULTIPOINT_PROB:
        return innovationCrossover(first, second)
    else:
        return singlepointCrossover(first, second)
