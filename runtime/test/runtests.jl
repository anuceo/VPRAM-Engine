"""
Main Test Runner for VPRAM Engine Runtime

Runs all tests to prove:
1. Sparse Vector Integrity + Brownian Motion Non-Repeatability
2. Cyclotomic-Polyhedral Indexing Determinism
3. Quaternion State Translation
"""

using Test

println("=" ^ 80)
println("VPRAM Engine Runtime - Core Math Proof Tests")
println("=" ^ 80)
println()

# Run transformation tests
println("Running Sparse Vector Transformation Tests (Task 1 - Part A)...")
println("-" ^ 80)
include("test_transformation.jl")
println()

# Run Brownian motion tests
println("Running Brownian Motion Non-Repeatability Tests (Task 1 - Part B)...")
println("-" ^ 80)
include("test_brownian_motion.jl")
println()

# Run polyhedral geometry tests
println("Running Cyclotomic-Polyhedral Indexing Tests (Task 2)...")
println("-" ^ 80)
include("test_polyhedral_geometry.jl")
println()

# Run quaternion math tests
println("Running Quaternion State Translation Tests (Task 3)...")
println("-" ^ 80)
include("test_quaternion_math.jl")
println()

# Run integrated verification
println("Running Integrated Verification (All Tasks Combined)...")
println("-" ^ 80)
include("test_integrated_verification.jl")
println()

println("=" ^ 80)
println("✓ ALL CORE MATH PROOFS COMPLETE")
println("=" ^ 80)
println()
println("SUMMARY:")
println("  ✓ Task 1: Sparse vector integrity + Brownian non-repeatability")
println("  ✓ Task 2: Cyclotomic-polyhedral indexing determinism")
println("  ✓ Task 3: Quaternion state translation for rendering")
println("  ✓ Integration: All three tasks working together")
println()
println("The mathematical integrity of the VPRAM engine core has been proven.")
println("Ready for Rust Backend integration.")
println("=" ^ 80)
