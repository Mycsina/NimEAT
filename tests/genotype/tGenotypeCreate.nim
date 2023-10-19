import ../../genotype

# Bias node is always node 0 and created by default
let geno = newGenotype()
assert geno.nodes.len == 1
assert geno.links.len == 0

# Add input and output nodes
# Non-input nodes are connected to bias node by default
geno.addNodeGene(INPUT, 1)
assert geno.nodes.len == 2
assert geno.links.len == 0
geno.addNodeGene(INPUT, 2)
assert geno.nodes.len == 3
assert geno.links.len == 0
geno.addNodeGene(OUTPUT, 3)
assert geno.nodes.len == 4
assert geno.links.len == 1

# Connect input nodes to output nodes
geno.connect()
assert geno.nodes.len == 4
assert geno.links.len == 3

# Initialize with 2 input nodes and 1 output node
let geno2 = newGenotype(2, 1)
assert geno2.nodes.len == 4
assert geno2.links.len == 3

# Check equality
assert geno.isSameTopology geno2

# Check cloning operations
assert geno != geno2
assert geno == geno.clone
assert geno2 == geno2.clone.clone
