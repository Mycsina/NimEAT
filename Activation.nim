import std/[math]

proc heaviside*(x: float): float =
    if x < 0.0:
        return 0.0
    elif x > 0.0:
        return 1.0
    else:
        return 0.5

proc sigmoid*(x: float): float =
    return 1.0 / (1.0 + exp(-x))

proc reLU*(x: float): float =
    return max(0.0, x)

proc leakyReLU*(x: float): float =
    return max(0.01 * x, x)

proc siLU*(x: float): float =
    return x * sigmoid(x)

proc softplus*(x: float): float =
    return ln(1.0 + exp(x))

proc mish*(x: float): float =
    return x * tanh(softplus(x))

# Useless for now

proc eLU*(x: float, alpha: float): float =
    if x < 0.0:
        return alpha * (exp(x) - 1.0)
    else:
        return x

proc squareplus*(x: float, beta: float): float =
    return (x + sqrt(x * x + beta)) / 2.0
