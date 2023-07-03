import std/[algorithm, sets]

type
    NType* = enum
        INPUT, HIDDEN, OUTPUT
    NodeGene* = object
        index*: int
        nType*: NType
    LinkGene* = object
        src*: int
        dst*: int
        weight*: float
        innovation*: int
        enabled*: bool
    Genotype* = ref object
        nodes*: seq[NodeGene]
        links*: seq[LinkGene]
        inputs*: int
        outputs*: int
        bracket*: int
        fitness*: float
        adjustedFitness*: float
        species*: int

var
    INNO_CONST = 1
    SEEN_INNO: HashSet[(int, int)]

proc unseen(src, dst: int): bool =
    result = (src, dst) notin SEEN_INNO

proc newNodeGene*(nodeType: NType, index: int): NodeGene =
    result.nType = nodeType
    result.index = index

proc newLinkGene*(src: int, dst: int, weight: float, enabled: bool): LinkGene =
    result.src = src
    result.dst = dst
    result.weight = weight
    result.enabled = enabled
    result.innovation = INNO_CONST
    if unseen(src, dst):
        SEEN_INNO.incl (src, dst)
        inc INNO_CONST


proc newGenotype*(): Genotype =
    result.nodes = @[]
    result.links = @[]
    result.inputs = 0
    result.outputs = 0


proc addNodeGene*(this: Genotype, nodeType: NType) =
    let v = newNodeGene(nodeType, this.nodes.len)
    this.nodes.add(v)
    if nodeType == NType.INPUT:
        inc this.inputs
    elif nodeType == NType.OUTPUT:
        inc this.outputs

proc addLinkGene*(this: Genotype, src: int, dst: int, weight: float, enabled: bool) =
    let l = newLinkGene(src, dst, weight, enabled)
    this.links.add(l)

proc addLinkGene*(this: Genotype, src: int, dst: int, weight: float, enabled: bool, innovation: int) =
    var l = newLinkGene(src, dst, weight, enabled)
    l.innovation = innovation
    this.links.add(l)

proc clone*(this: Genotype): Genotype =
    for n in this.nodes:
        result.addNodeGene(n.nType)
    for l in this.links:
        result.addLinkGene(l.src, l.dst, l.weight, l.enabled, l.innovation)

proc sortNodes*(this: Genotype) =
    this.nodes.sort(proc(a, b: NodeGene): int = a.index - b.index)

proc sortInnovation*(this: Genotype) =
    this.links.sort(proc(a, b: LinkGene): int = a.innovation - b.innovation)

proc sortTopology*(this: Genotype) =
    this.sortNodes()
    this.sortInnovation()

