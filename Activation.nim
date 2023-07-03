import std/[math]

type
    ActivationFunc* = concept x
        x(type float) is float

proc Heaviside*(x: float): float =
    if x < 0.0:
        return 0.0
    elif x > 0.0:
        return 1.0
    else:
        return 0.5

proc Sigmoid*(x: float): float =
    return 1.0 / (1.0 + exp(-x))

proc ReLU*(x: float): float =
    return max(0.0, x)

proc LeakyReLU*(x: float): float =
    return max(0.01 * x, x)
