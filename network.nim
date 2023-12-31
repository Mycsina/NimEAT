import std/[sequtils]

import activation
import genotype

import nimgraphviz

type
    Node* = ref object
        id*: int
        ntype*: NType
        ingoing*: seq[Link]
        value*: float
        function*: proc(x: float): float
        lastValues*: seq[float]
        activeSum*: float
        gotInput*: bool
        activationCount*: int
    Link* = ref object
        src*: int
        dst*: int
        weight*: float
        enabled*: bool
        timeDelay*: bool
    Network* = ref object
        nodes*: seq[Node]
        links*: seq[Link]
        inputs*: seq[Node]
        outputs*: seq[Node]
        score*: float
        blueprint*: Genotype

proc newNode*(ntype: NType, id: int): Node =
    result = new(Node)
    result.ntype = ntype
    result.id = id
    result.ingoing = newSeq[Link]()
    result.lastValues = newSeq[float](2)

proc newLink*(src, dst: int, weight: float, enabled: bool): Link =
    result = new(Link)
    result.src = src
    result.dst = dst
    result.weight = weight
    result.enabled = enabled

proc addNode*(p: Network, node: Node) =
    if node.ntype == BIAS:
        node.value = 1
    elif node.ntype == INPUT:
        p.inputs.add node
    elif node.ntype == OUTPUT:
        p.outputs.add node
    p.nodes.add node

proc addNode*(p: Network, nodeType: NType, id: int) =
    var n = newNode(nodeType, id)
    p.addNode(n)

proc findNode*(n: Network, id: int): Node =
    for node in n.nodes:
        if node.id == id:
            return node
    return nil

proc addLink*(n: Network, src, dst: int, weight: float, enabled: bool) =
    var l = newLink(src, dst, weight, enabled)
    n.links.add l
    let node = findNode(n, dst)
    if not node.isNil:
        node.ingoing.add l

proc generateNetwork*(g: Genotype): Network =
    result = new(Network)
    result.nodes = @[]
    result.links = @[]
    result.blueprint = g
    result.addNode(BIAS, 0)
    for node in g.nodes:
        result.addNode(node.nType, node.id)
        if node.nType != INPUT:
            result.addLink(0, node.id, randWeight(), true)
    for link in g.links:
        result.addLink(link.src, link.dst, link.weight, link.enabled)

proc outputsOff*(n: Network): bool =
    for node in n.outputs:
        if node.activationCount == 0:
            return true
    return false

proc predict*(n: Network, inputs: seq[float], activation: proc(x: float): float): seq[float] =
    for i in 0 ..< inputs.len:
        n.inputs[i].value = inputs[i]
    for node in n.nodes:
        if node.ntype != INPUT and node.ntype != BIAS:
            node.activeSum = 0
            node.gotInput = false
            for incoming in node.ingoing:
                let src = n.findNode(incoming.src)
                if not incoming.timeDelay:
                    node.activeSum += src.value * incoming.weight
                    if src.ntype == INPUT or src.gotInput:
                        node.gotInput = true
                else:
                    node.activeSum += incoming.weight * src.lastValues[0]
            if node.gotInput:
                node.lastValues[1] = node.lastValues[0]
                node.lastValues[0] = node.value
                node.value = activation(node.activeSum)
                inc node.activationCount
    return n.outputs.mapIt(it.value)


proc predict*(n: Network, inputs: seq[float]): seq[float] =
    result = predict(n, inputs, sigmoid)

proc toGraph*(this: Network): Graph[Edge] =
    var graph = newGraph[Edge]()
    for link in this.links:
        if link.enabled:
            graph.addEdge($link.src -- $link.dst)
    return graph
