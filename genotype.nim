{.experimental: "codeReordering".}

import std/[algorithm, tables, random]

import nimgraphviz

import params

randomize()

type
    NType* = enum
        INPUT, HIDDEN, OUTPUT, BIAS
    NodeGene* = object
        id*: int
        nType*: NType
    LinkGene* = object
        src*: int
        dst*: int
        weight*: float
        innovation*: int
        enabled*: bool
        mutDiff*: float
        isRecurrent*: bool
    Genotype* = ref object
        nodes*: seq[NodeGene] = @[]
        nodeIds*: set[uint16] = {}
        currNode*: int
        links*: seq[LinkGene] = @[]
        inputs*: int
        outputs*: int
        fitness*: float
        species*: int

var
    INNO_CONST* = 1
    SEEN_INNO* = newTable[(int, int), int](128)  # Pre-allocate for performance

proc resetInnovation*() =
    INNO_CONST = 1
    SEEN_INNO = newTable[(int, int), int]()

func newNodeGene*(nodeType: NType, id: int): NodeGene {.inline.} =
    result = NodeGene(id: id, nType: nodeType)

proc newLinkGene*(src: int, dst: int, weight: float, enabled: bool): LinkGene =
    result = LinkGene(src: src, dst: dst, weight: weight, enabled: enabled)
    if SEEN_INNO.hasKey((src, dst)):
        result.innovation = SEEN_INNO[(src, dst)]
    else:
        result.innovation = INNO_CONST
        SEEN_INNO[(src, dst)] = INNO_CONST
        inc INNO_CONST

proc newGenotype*(): Genotype =
    result = new Genotype
    result.addNodeGene(BIAS)

proc newGenotype*(inputs, outputs: int): Genotype =
    result = newGenotype()
    for i in 0 ..< inputs:
        result.addNodeGene(INPUT)
    for i in 0 ..< outputs:
        result.addNodeGene(OUTPUT)
    result.connect()

proc addNodeGene*(this: Genotype, nodeType: NType, id: int) =
    let v = newNodeGene(nodeType, id)
    this.nodes.add(v)
    # This should never happen
    this.nodeIds.incl(uint16(id))
    if nodeType == INPUT:
        inc this.inputs
    elif nodeType == OUTPUT:
        inc this.outputs
    inc this.currNode
    if nodeType != INPUT and nodeType != BIAS:
        this.addLinkGene(0, id, randWeight(), true)

proc addNodeGene*(this: Genotype, nodeType: NType) =
    this.addNodeGene(nodeType, this.currNode)

proc addLinkGene*(this: Genotype, src: int, dst: int, weight: float, enabled: bool) =
    let l = newLinkGene(src, dst, weight, enabled)
    this.links.add(l)

proc addLinkGene*(this: Genotype, src: int, dst: int, weight: float, enabled: bool, innovation: int) =
    var l = newLinkGene(src, dst, weight, enabled)
    l.innovation = innovation
    this.links.add(l)

proc clone*(this: Genotype): Genotype =
    return this.deepCopy()

proc clone*(this: LinkGene): LinkGene =
    return this.deepCopy()

func checkNode*(this: Genotype, id: int): bool {.inline, raises: [].} =
    return uint16(id) in this.nodeIds

proc sortNodes*(this: Genotype) =
    this.nodes.sort(proc(a, b: NodeGene): int = a.id - b.id)

func sortInnovation*(this: Genotype) =
    this.links.sort(proc(a, b: LinkGene): int = a.innovation - b.innovation)

func sortTopology*(this: Genotype) =
    this.sortNodes()
    this.sortInnovation()

func toGraph*(this: Genotype): Graph[Edge] =
    var graph = newGraph[Edge]()
    for link in this.links:
        if link.enabled:
            graph.addEdge($link.src -- $link.dst)
    return graph

## Operations

type
    mutType* = enum
        GAUSSIAN, COLDGAUSSIAN

proc randomSignal*(): int {.inline.} =
    # Randomly return 1 or -1
    if rand(1.0) > 0.5:
        return 1
    else:
        return -1

proc randWeight*(): float {.inline.} =
    # Randomly return a weight between -1 and 1
    return rand(1.0) * randomSignal().toFloat

proc gaussRand*(): float =
    ## Returns a normally distributed deviate with 0 mean and unit variance
    return gauss(0.0, 1.0)

proc connect*(this: Genotype) =
    ## Connect all input nodes to all output nodes
    for i in 1..this.inputs:
        for j in this.inputs+1..this.inputs+this.outputs:
            this.addLinkGene(i, j, randWeight(), true)

func isSameTopology*(a, b: Genotype): bool {.raises: [].} =
    ## Compare two genotypes
    if a.nodes.len != b.nodes.len:
        return false
    if a.links.len != b.links.len:
        return false
    for i in 0..a.nodes.high:
        if a.nodes[i].id != b.nodes[i].id:
            return false
        if a.nodes[i].nType != b.nodes[i].nType:
            return false
    for i in 0..a.links.high:
        if a.links[i].src != b.links[i].src:
            return false
        if a.links[i].dst != b.links[i].dst:
            return false
    return true

func `==`*(a: Genotype, b: Genotype): bool =
    ## Compare two genotypes
    if not a.isNil and not b.isNil:
        if isSameTopology(a, b):
            for i in 0..a.links.high:
                if a.links[i].weight != b.links[i].weight:
                    return false
                if a.links[i].enabled != b.links[i].enabled:
                    return false
            return true
        return false

proc speciationDistance*(first, second: Genotype): float =
    ## Calculate the NEAT speciation distance between two genotypes
    var
        numDisjoint = 0.0
        numExcess = 0.0
        numMatching = 0.0
        totalWeightDiff = 0.0
    let
        size1 = first.links.len
        size2 = second.links.len
        maxGenomeSize = max(size1, size2)
    var
        gene1, gene2: LinkGene
        i1, i2: int = 0
    while i1 < size1 or i2 < size2:
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
                totalWeightDiff += abs(gene1.weight - gene2.weight)
                i1 += 1
                i2 += 1
            elif p1innov < p2innov:
                i1 += 1
                numDisjoint += 1.0
            else:
                i2 += 1
                numDisjoint += 1.0
    let N = if maxGenomeSize < 20: 1.0 else: maxGenomeSize.toFloat
    let avgWeightDiff = if numMatching == 0.0: 0.0 else: totalWeightDiff / numMatching
    return param.DISJOINT_COEFF * (numDisjoint / N) + param.EXCESS_COEFF * (numExcess / N) + param.MUTDIFF_COEFF * avgWeightDiff

proc innovationCrossover*(first, second: Genotype): Genotype =
    ## Refactor this mess
    let
        firstFit = first.fitness
        secondFit = second.fitness
        child = newGenotype()
    var firstBetter = false
    if firstFit > secondFit:
        firstBetter = true
    elif firstFit == secondFit:
        firstBetter = first.links.len < second.links.len
    ## Add inputs, outputs to child
    for node in second.nodes:
        if node.nType in [INPUT, OUTPUT]:
            child.addNodeGene(node.nType, node.id)
    var
        fIter, sIter = 0
        fEnd = first.links.len
        sEnd = second.links.len
        fromWorse: bool ## Used to skip excess from worst
        chosenLink: LinkGene
    while not (fIter == fEnd and sIter == sEnd):
        fromWorse = false
        if fIter == fEnd:
            chosenLink = second.links[sIter]
            inc sIter
            if firstBetter: fromWorse = true
        elif sIter == sEnd:
            chosenLink = first.links[fIter]
            inc fIter
            if not firstBetter: fromWorse = true
        else:
            let
                firstLink = first.links[fIter]
                secondLink = second.links[sIter]
            if firstLink.innovation == secondLink.innovation:
                if rand(1.0) < 0.5:
                    chosenLink = firstLink
                else:
                    chosenLink = secondLink
                # chosenLink = firstLink.clone()
                # chosenLink.weight = (firstLink.weight + secondLink.weight) / 2
                # chosenLink.mutDiff = (firstLink.mutDiff + secondLink.mutDiff) / 2
                if firstLink.enabled == false or secondLink.enabled == false:
                    if rand(1.0) < param.DISABLED_GENE_INHERIT_PROB:
                        chosenLink.enabled = false
                inc fIter
                inc sIter
            elif firstLink.innovation < secondLink.innovation:
                chosenLink = firstLink
                inc fIter
                if not firstBetter: fromWorse = true
            elif firstLink.innovation > secondLink.innovation:
                chosenLink = secondLink
                inc sIter
                if firstBetter: fromWorse = true
        for link in child.links:
            if link.src == chosenLink.src and link.dst == chosenLink.dst:
                ## We already have this link, just skip
                fromWorse = true
                break
        if not fromWorse:
            ## Check if child has node genes for the link
            let
                inNode = chosenLink.src
                outNode = chosenLink.dst
            if not child.checkNode(inNode):
                child.addNodeGene(HIDDEN, inNode)
            if not child.checkNode(outNode):
                child.addNodeGene(HIDDEN, outNode)
            child.addLinkGene(inNode, outNode, chosenLink.weight, chosenLink.enabled, chosenLink.innovation)
    when defined(verbose):
        if child.links.len == 0:
            echo first.repr
            echo second.repr
            echo child.repr
    return child

proc mating*(first, second: Genotype): Genotype =
    if rand(1.0) < param.MATE_MULTIPOINT_PROB:
        return innovationCrossover(first, second)
    else:
        # TODO: Implement singlepoint crossover
        return innovationCrossover(first, second)
