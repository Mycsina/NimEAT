# NimEAT

NEAT (NeuroEvolution of Augmenting Topologies) implementation in Nim.

## Installation

Requires Nim 2.0+ and nimble.

```bash
nimble install
```

## Quick Start

```nim
import genotype
import network
import population
import species
import params

# Configure parameters
param.setPopSize(150)

# Create initial genome (2 inputs, 1 output)
var g = newGenotype(2, 1)

# Create and spawn population
let p = newPopulation()
p.spawn(g)

# Evolution loop
for generation in 1..100:
    for organism in p.population:
        # Evaluate fitness
        let output = organism.net.predict(@[1.0, 0.0])
        organism.fitness = computeFitness(output)
    
    p.advanceGeneration()
```

## Running the XOR Example

```bash
nimble runxor
```

## Commands

```bash
nimble test      # Run all tests
nimble testFast  # Run unit tests only (faster)
nimble bench     # Run benchmarks
nimble clear     # Clean build artifacts
```

## Parameters

Key parameters in `params.nim`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| POP_SIZE | 150 | Population size |
| COMPAT_THRESHOLD | 2.0 | Species compatibility threshold |
| MUT_ADD_NODE_PROB | 0.001 | Probability of adding a node |
| MUT_ADD_LINK_PROB | 0.15 | Probability of adding a link |
| MUT_WEIGHT_PROB | 0.9 | Probability of mutating weights |

Adjust via setters:
```nim
param.setPopSize(512)
param.setCompatThreshold(3.0)
```

## Project Structure

```
.
├── genotype.nim      # Genome representation
├── network.nim       # Neural network phenotype
├── species.nim       # Species and organism types
├── population.nim    # Population management
├── mutations.nim     # Mutation operators
├── params.nim        # Configuration parameters
├── activation.nim    # Activation functions
├── serialization.nim # JSON serialization
└── tests/            # Test suite
```

## Development

See [GEMINI.md](GEMINI.md) for tooling guidelines.

## License

MIT
