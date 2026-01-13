type
    NEATParams* = ref object
        POP_SIZE* = 150
        REGULAR_CULLING_AGE* = 20
        REGULAR_CULLING_INTERVAL* = 30
        MAX_GENERATIONS* = 100
        ENFORCED_DIVERSITY* = true
        SPECIES_DROPOFF_AGE* = 30
        DIVERSITY_TARGET* = 10
        SURVIVAL_THRESHOLD* = 0.3
        INTERSPECIES_MATE_RATE* = 0.01
        MATE_MULTIPOINT_PROB* = 1.0
        DISABLED_GENE_INHERIT_PROB* = 0.75
        COMPAT_THRESHOLD* = 2.0
        COMPATIBILITY_MODIFIER* = 0.2
        DISJOINT_COEFF* = 1.0
        EXCESS_COEFF* = 1.0
        MUTDIFF_COEFF* = 0.5
        BABIES_STOLEN* = 0
        MATE_ONLY_PROB* = 0.2
        DROPOFF_AGE* = 15
        AGE_SIGNIFICANCE* = 2.5
        MUT_ADD_LINK_PROB* = 0.15
        MUT_ADD_NODE_PROB* = 0.001
        MUT_WEIGHT_POWER* = 1.5
        MUT_WEIGHT_PROB* = 0.9
        MUT_ONLY_PROB* = 0.35
        MUT_TOGGLE_PROB* = 0.1
        MUT_REENABLE_PROB* = 0.05
        ALLOW_RECURRENT* = false
        RECURRENCE_RATE* = 0.05

var param* = new NEATParams

proc setPopSize*(self: NEATParams, size: int) =
    ## Sets population size of first generation
    assert size > 0, "POP_SIZE must be positive"
    self.POP_SIZE = size

proc setRegularCullingAge*(self: NEATParams, age: int) =
    ## Sets age where species start to be culled
    self.REGULAR_CULLING_AGE = age

proc setRegularCullingInterval*(self: NEATParams, interval: int) =
    ## Sets interval between culling
    self.REGULAR_CULLING_INTERVAL = interval

proc setEnforcedDiversity*(self: NEATParams, diversity: bool) =
    ## Sets if diversity is enforced
    self.ENFORCED_DIVERSITY = diversity

proc setDiversityTarget*(self: NEATParams, target: int) =
    ## Sets how many species should be kept
    self.DIVERSITY_TARGET = target

proc setSurvivalThreshold*(self: NEATParams, threshold: float) =
    ## Controls threshold of best organisms that reproduce
    assert threshold > 0.0 and threshold <= 1.0, "SURVIVAL_THRESHOLD must be in (0, 1]"
    self.SURVIVAL_THRESHOLD = threshold

proc setInterspeciesMateRate*(self: NEATParams, rate: float) =
    ## Sets probability of interspecies mating
    self.INTERSPECIES_MATE_RATE = rate

proc setMateMultipointProb*(self: NEATParams, prob: float) =
    ## Sets probability of multipoint crossover
    self.MATE_MULTIPOINT_PROB = prob

proc setDisabledGeneInheritProb*(self: NEATParams, prob: float) =
    ## Sets probability of inheriting disabled gene
    self.DISABLED_GENE_INHERIT_PROB = prob

proc setCompatThreshold*(self: NEATParams, threshold: float) =
    ## Sets compatibility threshold between two organisms for them to be same species
    self.COMPAT_THRESHOLD = threshold

proc setCompatibilityModifier*(self: NEATParams, modifier: float) =
    ## Sets how much should compatibility threshold be changed
    self.COMPATIBILITY_MODIFIER = modifier

proc setDisjointCoeff*(self: NEATParams, coeff: float) =
    ## Sets coefficient for disjoint genes
    self.DISJOINT_COEFF = coeff

proc setExcessCoeff*(self: NEATParams, coeff: float) =
    ## Sets coefficient for excess genes
    self.EXCESS_COEFF = coeff

proc setMutdiffCoeff*(self: NEATParams, coeff: float) =
    ## Sets coefficient for weight difference between genes
    self.MUTDIFF_COEFF = coeff

proc setBabiesStolen*(self: NEATParams, babies: int) =
    ## Sets number of babies stolen from other species
    self.BABIES_STOLEN = babies

proc setMateOnlyProb*(self: NEATParams, prob: float) =
    ## Sets probability of only mating without mutation
    self.MATE_ONLY_PROB = prob

proc setDropoffAge*(self: NEATParams, age: int) =
    ## Sets age before penalizing species for not improving
    self.DROPOFF_AGE = age

proc setAgeSignificance*(self: NEATParams, significance: float) =
    ## Sets how much should young species be protected
    self.AGE_SIGNIFICANCE = significance

proc setMutAddLinkProb*(self: NEATParams, prob: float) =
    ## Sets probability of adding a link
    self.MUT_ADD_LINK_PROB = prob

proc setMutAddNodeProb*(self: NEATParams, prob: float) =
    ## Sets probability of adding a node
    self.MUT_ADD_NODE_PROB = prob

proc setMutWeightPower*(self: NEATParams, power: float) =
    ## Sets modifier on weight mutation
    self.MUT_WEIGHT_POWER = power

proc setMutWeightProb*(self: NEATParams, prob: float) =
    ## Sets probability of weight mutation
    assert prob >= 0.0 and prob <= 1.0, "MUT_WEIGHT_PROB must be in [0, 1]"
    self.MUT_WEIGHT_PROB = prob

proc setMutOnlyProb*(self: NEATParams, prob: float) =
    ## Sets probability of mutating without mating
    self.MUT_ONLY_PROB = prob

proc setMutToggleProb*(self: NEATParams, prob: float) =
    ## Sets probability of toggling a link
    self.MUT_TOGGLE_PROB = prob

proc setMutReenableProb*(self: NEATParams, prob: float) =
    ## Sets probability of reenabling a link
    self.MUT_REENABLE_PROB = prob

proc setAllowRecurrent*(self: NEATParams, allow: bool) =
    ## Sets whether recurrent connections are allowed
    self.ALLOW_RECURRENT = allow

proc setRecurrenceRate*(self: NEATParams, rate: float) =
    ## Sets base probability of proposing a recurrent link during link mutation
    self.RECURRENCE_RATE = rate
