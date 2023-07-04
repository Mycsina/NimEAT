{.experimental: "codeReordering".}

import std/[algorithm, tables]

import nimgraphviz

var
    USE_BIAS = true

type
    NType* = enum
        INPUT, HIDDEN, OUTPUT, BIAS
    NodeGene* = object
        index*: int
        nType*: NType
    LinkGene* = object
        src*: int
        dst*: int
        weight*: float
        innovation*: int
        enabled*: bool
    # store output nodes separately so we can regularly iterate over nodes
    Genotype* = ref object
        nodes*: seq[NodeGene]
        links*: seq[LinkGene]
        inputs*: int
        outputs*: int
        bias*: bool
        fitness*: float
        adjustedFitness*: float
        species*: int

var
    INNO_CONST = 1
    SEEN_INNO = newTable[(int, int), int]()

proc newNodeGene*(nodeType: NType, index: int): NodeGene =
    result.nType = nodeType
    result.index = index

proc newLinkGene*(src: int, dst: int, weight: float, enabled: bool): LinkGene =
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

proc newGenotype*(bias: bool): Genotype =
    # This spawns a new genotype with no links and an optional bias node
    # The bias node is always the first node in the list, followed by the input nodes, then the output nodes and finally the hidden nodes.
    result = new Genotype
    result.nodes = @[]
    result.links = @[]
    result.inputs = 0
    result.outputs = 0
    result.bias = bias
    if bias:
        result.addNodeGene(NType.BIAS)

proc newGenotype*(): Genotype =
    return newGenotype(USE_BIAS)


proc addNodeGene*(this: Genotype, nodeType: NType) =
    ## Add link to bias node
    let
        nodeIdx = this.nodes.len
        v = newNodeGene(nodeType, nodeIdx)
    this.nodes.add(v)
    if nodeType == NType.INPUT:
        inc this.inputs
    elif nodeType == NType.OUTPUT:
        inc this.outputs
    # Connect to bias node if not input
    if (nodeType != INPUT and nodeType != BIAS) and this.bias:
        this.addLinkGene(0, nodeIdx, 1.0, true)


proc addLinkGene*(this: Genotype, src: int, dst: int, weight: float, enabled: bool) =
    let l = newLinkGene(src, dst, weight, enabled)
    this.links.add(l)

proc addLinkGene*(this: Genotype, src: int, dst: int, weight: float, enabled: bool, innovation: int) =
    var l = newLinkGene(src, dst, weight, enabled)
    l.innovation = innovation
    this.links.add(l)

proc clone*(this: Genotype): Genotype =
    result = newGenotype(true)
    for n in this.nodes:
        if n.nType != NType.BIAS:
            result.addNodeGene(n.nType)
    for l in this.links:
        result.addLinkGene(l.src, l.dst, l.weight, l.enabled, l.innovation)

proc inputIdx*(this: Genotype): int =
    result = this.bias.int

proc outputIdx*(this: Genotype): int =
    result = this.bias.int + this.inputs

proc hiddenIdx*(this: Genotype): int =
    result = this.bias.int + this.inputs + this.outputs

proc sortNodes*(this: Genotype) =
    this.nodes.sort(proc(a, b: NodeGene): int = a.index - b.index)

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
