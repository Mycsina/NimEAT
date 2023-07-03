import Activation
import Genotype

import nimgraphviz

type
    LType* = enum
        FORWARD, RECURRENT
    Node* = ref object
        ntype*: NType
        idx*: int
        incoming*: seq[Link]
        value*: float
    Link* = ref object
        lType*: LType
        src*: int
        dst*: int
        weight*: float
        enabled*: bool
        signal*: float
    Phenotype* = ref object
        nodes*: seq[Node]
        links*: seq[Link]
        inputs*: seq[Node]
        outputs*: seq[Node]
        score*: float
        blueprint*: Genotype

proc newNode*(ntype: NType): Node =
    result = new(Node)
    result.ntype = ntype
    result.incoming = newSeq[Link]()

proc newLink*(src, dst: int, weight: float, enabled: bool): Link =
    result = new(Link)
    result.src = src
    result.dst = dst
    result.weight = weight
    result.enabled = enabled

proc addNode*(p: Phenotype, nodeType: NType) =
    var n = newNode(nodeType)
    n.idx = p.nodes.len
    p.nodes.add n
    if nodeType == INPUT:
        p.inputs.add n
    elif nodeType == OUTPUT:
        p.outputs.add n

proc addLink*(p: Phenotype, src, dst: int, weight: float, enabled: bool) =
    var l = newLink(src, dst, weight, enabled)
    p.links.add l
    p.nodes[dst].incoming.add l

proc newPhenotype*(g: Genotype): Phenotype =
    result = new(Phenotype)
    result.nodes = @[]
    result.links = @[]
    result.blueprint = g
    for node in g.nodes:
        result.addNode(node.ntype)
    for link in g.links:
        result.addLink(link.src, link.dst, link.weight, link.enabled)

proc getOutputs*(p: Phenotype, inputs: seq[float], activation: proc(x: float): float): seq[float] =
    for i in 0 ..< inputs.len:
        p.inputs[i].value = inputs[i]
    for node in p.nodes:
        if node.ntype == INPUT:
            continue
        if node.ntype == HIDDEN or node.ntype == OUTPUT:
            node.value = 0.0
            for link in node.incoming:
                if link.enabled:
                    node.value += link.weight * p.nodes[link.src].value
            node.value = activation(node.value)
    result = newSeq[float](p.outputs.len)
    for i in 0 ..< p.outputs.len:
        result[i] = p.outputs[i].value

proc getOutputs*(p: Phenotype, inputs: seq[float]): seq[float] =
    result = getOutputs(p, inputs, sigmoid)

proc toGraph*(this: Phenotype): Graph[Edge] =
    var graph = newGraph[Edge]()
    for link in this.links:
        if link.enabled:
            graph.addEdge($link.src -- $link.dst)
    return graph
