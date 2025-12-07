"""
Brownian Motion Module

This module implements Brownian motion for the VPRAM engine to ensure non-repeatability
and introduce stochastic evolution in sparse vector operations. Brownian motion provides
a mathematical foundation for random but continuous evolution of system states.
"""
module BrownianMotion

using Random
using Statistics
using LinearAlgebra

export BrownianState, evolve!, get_displacement, reset!, set_seed!, 
       generate_noise, apply_brownian_kernel, verify_non_repeatability,
       compute_path_statistics, wiener_process

"""
    BrownianState

Represents the state of a Brownian motion process.
Tracks cumulative displacement and maintains internal random state.
"""
mutable struct BrownianState
    dimension::Int
    displacement::Vector{Float64}
    time::Float64
    rng::Random.AbstractRNG
    history::Vector{Vector{Float64}}
    
    function BrownianState(dimension::Int, seed::Union{Int, Nothing} = nothing)
        rng = seed === nothing ? Random.default_rng() : Random.MersenneTwister(seed)
        new(dimension, zeros(Float64, dimension), 0.0, rng, [])
    end
end

"""
    reset!(state::BrownianState)

Reset the Brownian motion state to initial conditions.
"""
function reset!(state::BrownianState)
    state.displacement .= 0.0
    state.time = 0.0
    empty!(state.history)
    return state
end

"""
    set_seed!(state::BrownianState, seed::Int)

Set a new random seed for the Brownian motion.
"""
function set_seed!(state::BrownianState, seed::Int)
    state.rng = Random.MersenneTwister(seed)
    return state
end

"""
    get_displacement(state::BrownianState)

Get the current displacement vector.
"""
get_displacement(state::BrownianState) = copy(state.displacement)

"""
    evolve!(state::BrownianState, dt::Float64, volatility::Float64 = 1.0)

Evolve the Brownian motion by time step dt with given volatility.
Uses the standard Brownian motion equation: dW = √(dt) * N(0,1) * volatility

Returns the incremental displacement for this step.
"""
function evolve!(state::BrownianState, dt::Float64, volatility::Float64 = 1.0)
    @assert dt > 0 "Time step must be positive"
    @assert volatility >= 0 "Volatility must be non-negative"
    
    # Generate standard normal random variables
    dW = sqrt(dt) * volatility * randn(state.rng, state.dimension)
    
    # Update cumulative displacement
    state.displacement .+= dW
    state.time += dt
    
    # Store in history
    push!(state.history, copy(state.displacement))
    
    return dW
end

"""
    generate_noise(dimension::Int, n_samples::Int, dt::Float64 = 1.0, 
                   volatility::Float64 = 1.0, seed::Union{Int, Nothing} = nothing)

Generate a sequence of Brownian motion increments.
Returns a matrix where each column is a time step.
"""
function generate_noise(dimension::Int, n_samples::Int, dt::Float64 = 1.0, 
                       volatility::Float64 = 1.0, seed::Union{Int, Nothing} = nothing)
    rng = seed === nothing ? Random.default_rng() : Random.MersenneTwister(seed)
    
    noise = zeros(Float64, dimension, n_samples)
    for i in 1:n_samples
        noise[:, i] = sqrt(dt) * volatility * randn(rng, dimension)
    end
    
    return noise
end

"""
    apply_brownian_kernel(values::Vector{T}, dt::Float64, volatility::Float64, 
                          seed::Union{Int, Nothing} = nothing) where T <: Number -> Vector{Float64}

Apply Brownian motion to a vector of values.
Each value evolves independently according to Brownian motion.
Note: Returns Vector{Float64} regardless of input type T due to noise being Float64.
"""
function apply_brownian_kernel(values::Vector{T}, dt::Float64, volatility::Float64,
                               seed::Union{Int, Nothing} = nothing) where T <: Number
    rng = seed === nothing ? Random.default_rng() : Random.MersenneTwister(seed)
    
    n = length(values)
    noise = sqrt(dt) * volatility * randn(rng, n)
    
    return values .+ noise
end

"""
    verify_non_repeatability(generator::Function, n_trials::Int = 100)

Verify that a random generation function produces non-repeating results.
Returns (is_unique, uniqueness_ratio, statistics)

The generator function should take no arguments and return a value or array.
"""
function verify_non_repeatability(generator::Function, n_trials::Int = 100)
    results = [generator() for _ in 1:n_trials]
    
    # Check if all results are unique (for scalar/vector results)
    unique_results = unique(results)
    uniqueness_ratio = length(unique_results) / n_trials
    
    # Calculate statistical properties if results are numeric
    if all(x -> x isa Number || x isa AbstractArray{<:Number}, results)
        if results[1] isa Number
            values = Float64.(results)
        else
            # For arrays, use the norm
            values = [norm(Float64.(r)) for r in results]
        end
        
        stats = (
            mean = mean(values),
            std = std(values),
            min = minimum(values),
            max = maximum(values),
            unique_count = length(unique_results),
            uniqueness_ratio = uniqueness_ratio
        )
    else
        stats = (
            unique_count = length(unique_results),
            uniqueness_ratio = uniqueness_ratio
        )
    end
    
    # Consider non-repeating if uniqueness ratio is very high
    # (allowing for rare collisions in floating point)
    is_unique = uniqueness_ratio > 0.95
    
    return (is_unique, uniqueness_ratio, stats)
end

"""
    compute_path_statistics(state::BrownianState)

Compute statistics about the Brownian motion path.
Returns mean displacement, variance, and path length.
"""
function compute_path_statistics(state::BrownianState)
    if isempty(state.history)
        return nothing
    end
    
    # Convert history to matrix for easier computation
    history_matrix = hcat(state.history...)
    
    # Compute statistics for each dimension
    means = mean(history_matrix, dims=2)
    variances = var(history_matrix, dims=2)
    
    # Compute total path length (sum of incremental distances)
    path_length = 0.0
    for i in 2:length(state.history)
        path_length += norm(state.history[i] - state.history[i-1])
    end
    
    return (
        mean_displacement = means,
        variance = variances,
        final_displacement = state.displacement,
        path_length = path_length,
        n_steps = length(state.history)
    )
end

"""
    wiener_process(t::Float64, dimension::Int = 1, n_points::Int = 1000,
                   seed::Union{Int, Nothing} = nothing)

Generate a standard Wiener process (Brownian motion) path from 0 to t.
Returns (times, paths) where paths is a matrix of dimension × n_points.
"""
function wiener_process(t::Float64, dimension::Int = 1, n_points::Int = 1000,
                       seed::Union{Int, Nothing} = nothing)
    @assert t > 0 "Time must be positive"
    @assert n_points > 1 "Need at least 2 points"
    
    dt = t / (n_points - 1)
    times = range(0, t, length=n_points)
    
    state = BrownianState(dimension, seed)
    paths = zeros(Float64, dimension, n_points)
    
    for i in 2:n_points
        evolve!(state, dt, 1.0)
        paths[:, i] = state.displacement
    end
    
    return (times = collect(times), paths = paths)
end

end # module
