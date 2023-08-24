var
    ## Population parameters
    # Population size of first generation
    POP_SIZE* = 200

    ## Reproduction parameters
    # Age where species start to be culled
    REGULAR_CULLING_AGE* = 5
    # Interval between culling
    REGULAR_CULLING_INTERVAL* = 2
    # If we ensure diversity
    ENFORCED_DIVERSITY* = false
    # How many species should be kept
    DIVERSITY_TARGET* = 3
    # Controls number of parents
    SURVIVAL_THRESHOLD* = 0.05
    # Probability of interspecies mating
    INTERSPECIES_MATE_RATE* = 0.001
    # Probability of multipoint crossover
    MATE_MULTIPOINT_PROB* = 1.0
    # Probability of inheriting disabled gene
    DISABLED_GENE_INHERIT_PROB* = 0.75

    ## Speciation parameters
    # Compatibility threshold between two organisms for them to be same species
    COMPAT_THRESHOLD* = 3.0
    # How much should compatibility threshold be changed
    COMPATIBILITY_MODIFIER* = 0.01
    # Coefficient for disjoint genes
    DISJOINT_COEFF* = 1.0
    # Coefficient for excess genes
    EXCESS_COEFF* = 1.0
    # Coefficient for weight difference between genes
    MUTDIFF_COEFF* = 2.0
    # Non-implemented
    BABIES_STOLEN* = 0

    ## Species parameters
    # Probability of only mating without mutation
    MATE_ONLY_PROB* = 0.2
    # Age before penalizing species for not improving
    DROPOFF_AGE* = 5
    # How much should young species be protected
    AGE_SIGNIFICANCE* = 1.0

    ## Mutation parameters
    # Probability of adding a link
    MUT_ADD_LINK_PROB* = 0.1
    # Probability of adding a node
    MUT_ADD_NODE_PROB* = 0.0025
    # Modifier on weight mutation
    MUT_WEIGHT_POWER* = 1.0
    # Probability of weight mutation
    MUT_WEIGHT_PROB* = 0.9
    # Probability of mutating without mating
    MUT_ONLY_PROB* = 0.25
    # Probability of toggling a link
    MUT_TOGGLE_PROB* = 0.00
    # Probability of reenabling a link
    MUT_REENABLE_PROB* = 0.00
