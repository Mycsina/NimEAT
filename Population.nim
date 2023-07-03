import std/[random]

import Genotype
import Species
import Phenotype
import Operations

randomize()

var
    POP_SIZE = 256
    INPUT_SIZE = 2
    HIDDEN_SIZE = 0
    OUTPUT_SIZE = 1
var
    NEW_LINK_CHANCE = 0.05
    NEW_NODE_CHANCE = 0.03
    ELITISM = 15
    MAX_STALENESS = 15

type
    Population* = ref object
        currentGeneration*: int
        genetics*: seq[Genotype]
        species*: seq[Species]
        population*: seq[Phenotype]

proc newPopulation*(): Population =
    result = new(Population)
    result.currentGeneration = 0
    result.genetics = @[]
    result.species = @[]
    result.population = @[]

proc averageFitness*(p: Population): float =
    var sum = 0.0
    for s in p.species:
        sum += s.averageFitness
    echo sum
    result = sum / p.species.len.toFloat

proc spawnBaseGenotype*(inputs, outputs: int): Genotype =
    result = newGenotype()
    for i in 0 ..< inputs:
        result.addNodeGene(INPUT)
    for i in 0 ..< outputs:
        result.addNodeGene(OUTPUT)
    for i in 0 ..< HIDDEN_SIZE:
        result.addNodeGene(HIDDEN)
    # Fully connect input to layer, layer to output
    for i in 0 ..< inputs:
        if HIDDEN_SIZE > 0:
            for j in 0 ..< HIDDEN_SIZE:
                let weight = rand(1.0)
                result.addLinkGene(result.inputIdx + i, result.hiddenIdx + j, weight, true)
        else:
            for j in 0 ..< outputs:
                let weight = rand(1.0)
                result.addLinkGene(result.inputIdx + i, result.outputIdx + j, weight, true)
    for i in 0 ..< HIDDEN_SIZE:
        for j in 0 ..< outputs:
            let weight = rand(1.0)
            result.addLinkGene(result.hiddenIdx + i, result.outputIdx + j, weight, true)
    return result

proc spawnPerSpecies*(p: Population, s: Species): int =
    var adjustedSum = 0.0
    for i in 0 ..< s.members.len:
        adjustedSum += s.members[i].adjustedFitness
    result = (adjustedSum / p.averageFitness).toInt

proc spawnOffspring*(p: Population, crossover: Crossover, mut: varargs[Mutation]) =
    for s in p.species:
        let spawn = p.spawnPerSpecies(s)
        for i in 0 ..< spawn:
            let
                p1 = s.members[rand(s.members.len)]
                p2 = s.members[rand(s.members.len)]
            var child = crossover(p1, p2)
            for m in mut:
                child = mut(child)
            p.genetics.add(child)

proc spawnOffspring*(p: Population) =
    for s in p.species:
        let spawn = p.spawnPerSpecies(s)
        for i in 0 ..< spawn:
            let
                p1 = s.members[max(rand(s.members.len) - 1, 0)]
                p2 = s.members[max(rand(s.members.len) - 1, 0)]
            var child = p1.innovationCrossover(p2)
            let node = rand(1.0)
            if node < NEW_NODE_CHANCE:
                child = child.addNodeMutation()
            let link = rand(1.0)
            if link < NEW_LINK_CHANCE:
                child = child.addLinkMutation()
            p.genetics.add(child)

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
        p.species[i].sortMembers()
        if p.species[i].members[0].fitness > p.species[i].topFitness:
            p.species[i].topFitness = p.species[i].members[0].fitness
            p.species[i].staleness = 0
        if p.species[i].staleness > MAX_STALENESS:
            p.species.del(i)
            dec CURR_SPECIES
            speciesNum -= 1
        else:
            p.species[i].staleness += 1

proc removeWeakGenotypes*(p: Population) =
    for s in p.species:
        s.removeWeakGenotypes(ELITISM)

proc advanceGeneration*(this: Population) =
    this.currentGeneration += 1
    # Remove worst performers and non-developing species
    this.updateStaleness()
    this.removeWeakGenotypes()
    # Spawn offspring from the survivors
    this.spawnOffspring()
    # Update species
    this.clusterToSpecies()
    # Spawn population
    this.spawnPopulation()

proc evaluate*(p: Population, fitness: proc(x: Phenotype): float) =
    for organism in p.population:
        organism.score = fitness(organism)
        organism.blueprint.fitness = organism.score


proc initialize*(): Population =
    result = newPopulation()
    for i in 0 ..< POP_SIZE:
        let g = spawnBaseGenotype(INPUT_SIZE, OUTPUT_SIZE)
        result.genetics.add(g)
    result.clusterToSpecies()
    result.spawnPopulation()

proc run*(p: Population, fitness: proc(x: Phenotype): float, fitness_goal: proc(x: float): bool) =
    var i = 0
    while true:
        if i == 3: break
        p.evaluate(fitness)
        echo "Generation: ", p.currentGeneration
        echo "Average fitness: ", p.averageFitness
        echo "Best fitness: ", p.genetics[0].fitness
        echo "Individuals: ", p.genetics.len
        echo "Species: ", p.species.len
        if fitness_goal(p.genetics[0].fitness):
            break
        p.advanceGeneration()
        i += 1
