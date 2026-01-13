import std/[math]

import ../../activation
import ../../genotype
import ../../network

## Create a basic 2-input to 1-output network with no activation function
var net = Network()
var
    b = newNode(BIAS, 0)
    i1 = newNode(INPUT, 1)
    i2 = newNode(INPUT, 2)
    o1 = newNode(OUTPUT, 3)
net.addNode(b)
net.addNode(i1)
net.addNode(i2)
net.addNode(o1)
net.addLink(b.id, o1.id, 0.5, true)
net.addLink(i1.id, o1.id, 0.2, true)
net.addLink(i2.id, o1.id, 0.2, true)
assert net.nodes.len == 4
assert net.predict(@[1.toFloat, 1.toFloat], linear)[0].round(1) == 0.9
## Try sigmoid activation
assert net.predict(@[1.toFloat, 1.toFloat])[0].round(2) == sigmoid(0.9).round(2)

## Create a recurrent 2:1:1 network with the hidden output feeding back to itself
net = Network()
b = newNode(BIAS, 0)
i1 = newNode(INPUT, 1)
i2 = newNode(INPUT, 2)
var
    h1 = newNode(HIDDEN, 3)
o1 = newNode(OUTPUT, 4)
net.addNode(b)
net.addNode(i1)
net.addNode(i2)
net.addNode(h1)
net.addNode(o1)
net.addLink(b.id, h1.id, 0.5, true)
net.addLink(i1.id, h1.id, 0.1, true)
net.addLink(i2.id, h1.id, 0.1, true)
net.addLink(h1.id, h1.id, 0.1, true)
net.addLink(h1.id, o1.id, 1, true)
assert net.nodes.len == 5
assert net.predict(@[1.toFloat, 1.toFloat], linear)[0].round(3) == 0.7
assert net.predict(@[1.toFloat, 1.toFloat], linear)[0].round(3) == 0.77
assert net.predict(@[1.toFloat, 1.toFloat], linear)[0].round(3) == 0.777
