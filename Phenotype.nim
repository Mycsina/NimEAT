import Activation
import Genotype

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

proc newNode*(ntype: NType): Node =
    result.ntype = ntype
    result.incoming = newSeq[Link]()

proc newLink*(src, dst: int, weight: float, enabled: bool): Link =
    result.src = src
    result.dst = dst
    result.weight = weight
    result.enabled = enabled

proc addNode*(p: Phenotype, nodeType: NType) =
    var n = newNode(nodeType)
    p.nodes.add n
    if nodeType == INPUT:
        p.inputs.add n
    elif nodeType == OUTPUT:
        p.outputs.add n

proc addLink*(p: Phenotype, src, dst: int, weight: float, enabled: bool) =
    var l = newLink(src, dst, weight, enabled)
    p.links.add l
    p.nodes[src].incoming.add l

proc newPhenotype*(g: Genotype): Phenotype =
    result.nodes = newSeq[Node]()
    result.links = newSeq[Link]()
    for node in g.nodes:
        result.nodes.add newNode(node.ntype)
        if node.ntype == INPUT:
            result.inputs.add result.nodes[high(result.nodes)]
        elif node.ntype == OUTPUT:
            result.outputs.add result.nodes[high(result.nodes)]
    for link in g.links:
        result.links.add newLink(link.src, link.dst, link.weight, link.enabled)

proc getPrediction*(p: Phenotype, inputs: seq[float], activation: ActivationFunc): seq[float] =
    for i in 0 ..< inputs.len:
        p.inputs[i].value = inputs[i]
    for node in p.nodes:
        if node.ntype == HIDDEN or node.ntype == OUTPUT:
            node.value = 0.0
            for link in node.incoming:
                if link.enabled:
                    node.value += link.weight * p.nodes[link.src].value
            node.value = activation(node.value)
    result = newSeq[float](p.outputs.len)
    for i in 0 ..< p.outputs.len:
        result[i] = p.outputs[i].value
