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
    # separate links into forward and recurrent
    Link* = ref object
        lType*: LType
        src*: int
        dst*: int
        weight*: float
        enabled*: bool
        signal*: float
    Network* = ref object
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

proc addNode*(p: Network, nodeType: NType) =
    var n = newNode(nodeType)
    if n.ntype == BIAS:
        n.value = 1
    n.idx = p.nodes.len
    p.nodes.add n
    if nodeType == INPUT:
        p.inputs.add n
    elif nodeType == OUTPUT:
        p.outputs.add n

proc addLink*(n: Network, src, dst: int, weight: float, enabled: bool) =
    var l = newLink(src, dst, weight, enabled)
    n.links.add l
    n.nodes[dst].incoming.add l

proc generateNetwork*(g: Genotype): Network =
    result = new(Network)
    result.nodes = @[]
    result.links = @[]
    result.blueprint = g
    for node in g.nodes:
        result.addNode(node.ntype)
    # TODO: handle RNNs (we need to store previous state)
    for link in g.links:
        result.addLink(link.src, link.dst, link.weight, link.enabled)

# TODO: handle RNNs
proc predict*(n: Network, inputs: seq[float], activation: proc(x: float): float): seq[float] =
    for i in 0 ..< inputs.len:
        n.inputs[i].value = inputs[i]
    for node in p.nodes:
        if node.ntype == INPUT or node.ntype == BIAS:
            continue
        node.value = 0.0
        for link in node.incoming:
            if link.enabled:
                node.value += link.weight * n.nodes[link.src].value
        node.value = activation(node.value)
    result = newSeq[float](p.outputs.len)
    for i in 0 ..< n.outputs.len:
        result[i] = n.outputs[i].value

proc predict*(n: Network, inputs: seq[float]): seq[float] =
    result = predict(n, inputs, sigmoid)

proc toGraph*(this: Network): Graph[Edge] =
    var graph = newGraph[Edge]()
    for link in this.links:
        if link.enabled:
            graph.addEdge($link.src -- $link.dst)
    return graph
