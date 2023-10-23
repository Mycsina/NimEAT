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
    SEEN_INNO* = newTable[(int, int), int]()

proc resetInnovation*() =
    INNO_CONST = 1
    SEEN_INNO = newTable[(int, int), int]()

func newNodeGene*(nodeType: NType, id: int): NodeGene =
    result = NodeGene(id: id, nType: nodeType)

proc newLinkGene*(src: int, dst: int, weight: float, enabled: bool): LinkGene =
    result = LinkGene(src: src, dst: dst, weight: weight, enabled: enabled)
    if src != 0:
        if SEEN_INNO.hasKey((src, dst)):
            result.innovation = SEEN_INNO[(src, dst)]
        else:
            result.innovation = INNO_CONST
            SEEN_INNO[(src, dst)] = INNO_CONST
            inc INNO_CONST

proc newGenotype*(): Genotype =
    result = new Genotype

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

func checkNode*(this: Genotype, id: int): bool =
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
            this.addLinkGene(i, j, randWeight(), true)

func isSameTopology*(a: Genotype, b: Genotype): bool =
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
    ## Calculate the speciation distance between two genotypes
    var
        numDisjoint = 0.0
        numExcess = 0.0
        numMatching = 0.0
        totalMutDiff = 0.0
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
                mutDiff = abs(gene1.mutDiff - gene2.mutDiff)
            totalMutDiff += mutDiff
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
    return param.DISJOINT_COEFF * numDisjoint + param.EXCESS_COEFF * numExcess + param.MUTDIFF_COEFF * (
            totalMutDiff /
            numMatching)

proc innovationCrossover*(first, second: Genotype): Genotype =
    ## Refactor this mess
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
    ## Add inputs, outputs to child
    for node in second.nodes:
        if node.nType in [INPUT, OUTPUT]:
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
                fLink = first.links[fIter]
                sLink = second.links[sIter]
            if fInnov == sInnov:
                # Clone first link
                chosenLink = fLink.clone()
                # Average weights
                chosenLink.weight = (fLink.weight + sLink.weight) / 2
                # Average mutDiff
                chosenLink.mutDiff = (fLink.mutDiff + sLink.mutDiff) / 2
                if fLink.enabled == false or sLink.enabled == false:
                    if rand(1.0) < param.DISABLED_GENE_INHERIT_PROB:
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
            child.addLinkGene(inNode, outNode, chosenLink.weight, chosenLink.enabled)
    return child

proc mating*(first, second: Genotype): Genotype =
    if rand(1.0) < param.MATE_MULTIPOINT_PROB:
        return innovationCrossover(first, second)
    else:
        # TODO: Implement singlepoint crossover
        return innovationCrossover(first, second)
