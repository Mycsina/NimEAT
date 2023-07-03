import Genotype
import Species
import Phenotype

var
    POP_SIZE = 256
    INPUT_SIZE = 24
    OUTPUT_SIZE = 4
    MAX_STALENESS = 15

type
    Population* = ref object
        currentGeneration*: int
        species*: seq[Species]
        genetics*: seq[Genotype]
        population*: seq[Phenotype]

proc spawnBaseGenotype*(inputs, outputs: int): Genotype =
    for i in 0 ..< inputs:
        result.addNodeGene(INPUT)
    for i in 0 ..< outputs:
        result.addNodeGene(OUTPUT)
    result.addLinkGene(0, inputs, 1.0, true)

proc spawnPopulation*(this: Population) =
    for i in 0 ..< POP_SIZE:
        this.genetics[i].fitness = 0.0
        this.genetics[i].adjustedFitness = 0.0
        let p = this.genetics[i].newPhenotype()
        this.population.add(p)

proc clusterToSpecies*(p: Population) =
    for g in p.genetics:
        var found = false
        for s in p.species:
            if s.isCompatible(g):
                s.addGenotype(g)
                found = true
                break
        if not found:
            let species = g.newSpecies()
            p.species.add(species)

proc updateStaleness*(p: Population) =
    var speciesNum = p.species.len
    for i in 0 ..< speciesNum:
        let s = p.species[i]
        if s.members.len == 1:
            continue
        if s.members[0].fitness > s.topFitness:
            s.topFitness = s.members[0].fitness
            s.staleness = 0
        else:
            inc s.staleness
        if s.staleness > MAX_STALENESS:
            p.species.del(i)
            dec speciesNum

proc initialize*(this: Population) =
    for i in 0 ..< POP_SIZE:
        let g = spawnBaseGenotype(INPUT_SIZE, OUTPUT_SIZE)
        this.genetics.add(g)
    this.clusterToSpecies()
    this.spawnPopulation()

proc sharedFitness*(g: var Genotype, p: Population) =
    g.adjustedFitness = g.fitness / p.species[g.species].members.len.toFloat
