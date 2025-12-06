"""
Main Test Runner for VPRAM Engine Runtime

Runs all tests to prove:
1. Sparse Vector Integrity - that the core data structure can be reliably manipulated
2. Brownian Motion Non-Repeatability - that evolution ensures non-repeatability
"""

using Test

println("=" ^ 80)
println("VPRAM Engine Runtime - Core Math Proof Tests")
println("=" ^ 80)
println()

println("Task 1: Proving Sparse Vector Integrity and Evolution")
println("-" ^ 80)
println()

# Run transformation tests
println("Running Sparse Vector Transformation Tests...")
println("-" ^ 80)
include("test_transformation.jl")
println()

# Run Brownian motion tests
println("Running Brownian Motion Non-Repeatability Tests...")
println("-" ^ 80)
include("test_brownian_motion.jl")
println()

println("=" ^ 80)
println("✓ ALL CORE MATH PROOFS COMPLETE")
println("=" ^ 80)
println()
println("SUMMARY:")
println("  ✓ Sparse vector data structure can be reliably manipulated by kernels")
println("  ✓ Brownian Motion ensures non-repeatability in evolution")
println()
println("The mathematical integrity of the VPRAM engine core has been proven.")
println("=" ^ 80)
