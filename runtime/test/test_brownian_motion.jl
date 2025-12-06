"""
Tests for Brownian Motion Module

These tests prove that Brownian motion ensures non-repeatability and 
provides proper stochastic evolution for sparse vector operations.
"""

using Test
using Random
using Statistics
using LinearAlgebra

# Add the src directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, "../src"))

include("../src/math/brownian_motion.jl")
using .BrownianMotion

@testset "Brownian Motion Non-Repeatability Tests" begin
    
    @testset "Basic State Construction" begin
        state = BrownianState(3)
        
        @test state.dimension == 3
        @test length(state.displacement) == 3
        @test all(state.displacement .== 0.0)
        @test state.time == 0.0
        @test isempty(state.history)
    end
    
    @testset "State Evolution Changes Displacement" begin
        state = BrownianState(5, 42)  # Fixed seed for reproducibility in this test
        
        initial_displacement = copy(state.displacement)
        
        # Evolve the state
        dW = evolve!(state, 1.0, 1.0)
        
        # Verify displacement changed
        @test state.displacement != initial_displacement
        @test state.time == 1.0
        @test length(state.history) == 1
        @test dW == state.displacement  # First step
    end
    
    @testset "Reset Functionality" begin
        state = BrownianState(3, 123)
        
        # Evolve several steps
        for _ in 1:5
            evolve!(state, 1.0)
        end
        
        @test state.time > 0.0
        @test !all(state.displacement .== 0.0)
        @test !isempty(state.history)
        
        # Reset
        reset!(state)
        
        @test state.time == 0.0
        @test all(state.displacement .== 0.0)
        @test isempty(state.history)
    end
    
    @testset "Seed Control for Reproducibility" begin
        seed = 12345
        
        # Create two states with same seed
        state1 = BrownianState(4, seed)
        state2 = BrownianState(4, seed)
        
        # Evolve both identically
        for _ in 1:10
            evolve!(state1, 0.1, 1.0)
            evolve!(state2, 0.1, 1.0)
        end
        
        # They should be identical
        @test state1.displacement ≈ state2.displacement
    end
    
    @testset "Non-Repeatability Without Seed" begin
        # Create multiple states without fixed seeds
        states = [BrownianState(3) for _ in 1:10]
        
        # Evolve all states
        for state in states
            evolve!(state, 1.0, 1.0)
        end
        
        # Extract final displacements
        displacements = [state.displacement for state in states]
        
        # Verify all displacements are unique (proving non-repeatability)
        unique_displacements = unique(displacements)
        @test length(unique_displacements) == length(displacements)
        
        println("  ✓ Verified: 10 independent Brownian motions produced 10 unique trajectories")
    end
    
    @testset "Statistical Properties of Brownian Motion" begin
        # Test that Brownian motion has correct statistical properties
        n_trials = 1000
        dimension = 1
        dt = 1.0
        
        # Generate many samples
        samples = []
        for _ in 1:n_trials
            state = BrownianState(dimension)
            dW = evolve!(state, dt, 1.0)
            push!(samples, dW[1])
        end
        
        # For standard Brownian motion: E[dW] ≈ 0, Var[dW] ≈ dt
        sample_mean = mean(samples)
        sample_var = var(samples)
        
        # Allow for statistical variation (within 3 standard errors)
        @test abs(sample_mean) < 0.1  # Mean should be close to 0
        @test abs(sample_var - dt) < 0.1  # Variance should be close to dt
        
        println("  ✓ Verified: Brownian motion has correct statistical properties")
        println("    Mean: $(round(sample_mean, digits=4)) (expected ≈ 0)")
        println("    Variance: $(round(sample_var, digits=4)) (expected ≈ $(dt))")
    end
    
    @testset "Noise Generation Non-Repeatability" begin
        # Generate noise without seed multiple times
        noise_samples = []
        
        for _ in 1:20
            noise = generate_noise(5, 10, 1.0, 1.0)
            push!(noise_samples, noise)
        end
        
        # Verify all samples are unique
        unique_samples = unique(noise_samples)
        @test length(unique_samples) == length(noise_samples)
        
        println("  ✓ Verified: 20 noise generations produced 20 unique results")
    end
    
    @testset "Brownian Kernel Application" begin
        values = [1.0, 2.0, 3.0, 4.0, 5.0]
        
        # Apply Brownian motion multiple times
        results = []
        for _ in 1:15
            result = apply_brownian_kernel(values, 0.1, 0.5)
            push!(results, result)
        end
        
        # Verify all results are unique (non-repeating)
        unique_results = unique(results)
        @test length(unique_results) == length(results)
        
        # Verify results are different from original
        for result in results
            @test result != values
        end
        
        println("  ✓ Verified: 15 Brownian kernel applications produced 15 unique outputs")
    end
    
    @testset "Verify Non-Repeatability Function" begin
        # Test the verification function itself with truly random generator
        generator = () -> rand(5)
        
        is_unique, ratio, stats = verify_non_repeatability(generator, 50)
        
        @test is_unique == true
        @test ratio > 0.95  # Should be essentially 1.0 for random data
        @test stats.unique_count == 50
        
        println("  ✓ Verified: Non-repeatability verification works correctly")
        println("    Uniqueness ratio: $(round(ratio, digits=4))")
    end
    
    @testset "Verify Non-Repeatability of Brownian Evolution" begin
        # Use verify_non_repeatability to test Brownian motion
        generator = () -> begin
            state = BrownianState(3)
            evolve!(state, 1.0, 1.0)
            return state.displacement
        end
        
        is_unique, ratio, stats = verify_non_repeatability(generator, 100)
        
        @test is_unique == true
        @test ratio == 1.0  # Should be exactly 1.0 for continuous random variables
        @test stats.unique_count == 100
        
        println("  ✓ Verified: 100 Brownian evolutions were all unique")
        println("    Mean norm: $(round(stats.mean, digits=4))")
        println("    Std dev: $(round(stats.std, digits=4))")
    end
    
    @testset "Path Statistics" begin
        state = BrownianState(2, 999)
        
        # Evolve for several steps
        for _ in 1:100
            evolve!(state, 0.1, 1.0)
        end
        
        stats = compute_path_statistics(state)
        
        @test stats !== nothing
        @test stats.n_steps == 100
        @test stats.path_length > 0.0
        @test length(stats.mean_displacement) == 2
        @test length(stats.variance) == 2
        @test length(stats.final_displacement) == 2
        
        println("  ✓ Verified: Path statistics computed correctly")
        println("    Steps: $(stats.n_steps)")
        println("    Path length: $(round(stats.path_length, digits=4))")
    end
    
    @testset "Wiener Process Generation" begin
        t = 10.0
        dimension = 3
        n_points = 100
        
        times, paths = wiener_process(t, dimension, n_points, 12345)
        
        @test length(times) == n_points
        @test size(paths) == (dimension, n_points)
        @test times[1] == 0.0
        @test times[end] ≈ t
        @test all(paths[:, 1] .== 0.0)  # Starts at origin
        
        println("  ✓ Verified: Wiener process generated correctly")
    end
    
    @testset "Multiple Independent Paths Non-Repeatability" begin
        # Generate multiple independent Wiener processes
        n_processes = 10
        all_paths = []
        
        for _ in 1:n_processes
            _, paths = wiener_process(5.0, 1, 50)
            push!(all_paths, paths)
        end
        
        # Verify all paths are unique
        unique_paths = unique(all_paths)
        @test length(unique_paths) == n_processes
        
        println("  ✓ Verified: $n_processes independent Wiener processes were all unique")
    end
    
    @testset "Volatility Scaling" begin
        # Test that volatility correctly scales the noise
        state_low = BrownianState(100, 123)
        state_high = BrownianState(100, 123)
        
        # Evolve with different volatilities
        dW_low = evolve!(state_low, 1.0, 0.1)
        
        # Reset RNG to same state
        set_seed!(state_high, 123)
        dW_high = evolve!(state_high, 1.0, 10.0)
        
        # Higher volatility should give larger displacements
        @test norm(dW_high) > norm(dW_low)
        
        println("  ✓ Verified: Volatility scaling works correctly")
    end
    
    @testset "Continuous Evolution Non-Repeatability" begin
        # Simulate continuous evolution and verify each step is unique
        state = BrownianState(4)
        
        previous_displacements = []
        for _ in 1:30
            evolve!(state, 0.1, 1.0)
            push!(previous_displacements, copy(state.displacement))
        end
        
        # Verify all states in the trajectory are unique
        unique_states = unique(previous_displacements)
        @test length(unique_states) == 30
        
        println("  ✓ Verified: 30 consecutive evolution steps produced 30 unique states")
    end
    
    @testset "Integration Test: Brownian Evolution of Sparse Vector Values" begin
        # This tests the integration of Brownian motion with sparse vector operations
        
        # Create initial values
        initial_values = [10.0, 20.0, 30.0, 40.0, 50.0]
        
        # Apply Brownian evolution multiple times
        evolved_values = []
        for _ in 1:25
            values = apply_brownian_kernel(initial_values, 0.5, 1.0)
            push!(evolved_values, values)
        end
        
        # Verify all evolved states are unique
        unique_evolved = unique(evolved_values)
        @test length(unique_evolved) == 25
        
        # Verify evolved values are different from initial
        for vals in evolved_values
            @test vals != initial_values
        end
        
        println("  ✓ Verified: Brownian evolution of sparse vector values ensures non-repeatability")
        println("    25 evolution steps produced 25 unique value sets")
    end
    
end

println("\n✓ All Brownian Motion Non-Repeatability Tests Passed!")
println("  Proved: Brownian Motion ensures non-repeatability in sparse vector evolution")
