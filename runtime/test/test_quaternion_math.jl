"""
Tests for Quaternion State Translation (Task 3)

These tests prove that sparse vectors can be correctly translated to valid unit quaternions
for rendering, with predictable changes based on attribute modifications.
"""

using Test
using LinearAlgebra

# Add the src directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, "../src"))

include("../src/math/quaternion_math.jl")
using .QuaternionMath

@testset "Quaternion State Translation Tests" begin
    
    @testset "Basic Quaternion Construction" begin
        q = Quaternion(1.0, 0.0, 0.0, 0.0)
        @test q.w == 1.0
        @test q.x == 0.0
        @test q.y == 0.0
        @test q.z == 0.0
    end
    
    @testset "Quaternion Normalization" begin
        # Non-unit quaternion
        q = Quaternion(2.0, 3.0, 4.0, 5.0)
        q_norm = normalize_quaternion(q)
        
        # Check it's now a unit quaternion
        @test is_unit_quaternion(q_norm)
        
        # Identity quaternion should remain unchanged
        q_identity = Quaternion(1.0, 0.0, 0.0, 0.0)
        q_identity_norm = normalize_quaternion(q_identity)
        @test is_unit_quaternion(q_identity_norm)
    end
    
    @testset "Task 3 Verification: Attribute to Quaternion Mapping (Main Requirement)" begin
        println("\n  Task 3 Core Verification:")
        println("  " * "="^60)
        
        # Starting attributes (representing a Spirit)
        fluidity_initial = 0.5
        mass = 1.0
        rigidity = 0.5
        
        println("  Initial Attributes:")
        println("    Fluidity: $fluidity_initial")
        println("    Mass: $mass")
        println("    Rigidity: $rigidity")
        
        # Translation: Map to quaternion
        q_initial = attribute_to_quaternion(fluidity_initial, mass, rigidity)
        println("\n  Initial Quaternion: q = ($(q_initial.w), $(q_initial.x), $(q_initial.y), $(q_initial.z))")
        
        # VERIFICATION 1: Assert output is a valid unit quaternion
        @test is_unit_quaternion(q_initial, 1e-6)
        norm_squared = q_initial.w^2 + q_initial.x^2 + q_initial.y^2 + q_initial.z^2
        println("  ||q||² = $(round(norm_squared, digits=6)) ≈ 1.0")
        println("  ✓ VERIFIED: Output is a valid unit quaternion")
        
        # Modify fluidity attribute (as per requirement: 0.5 -> 0.6)
        fluidity_modified = 0.6
        println("\n  Modified Attributes:")
        println("    Fluidity: $fluidity_initial → $fluidity_modified (increased by 0.1)")
        
        # Translation: Map modified attributes to quaternion
        q_modified = attribute_to_quaternion(fluidity_modified, mass, rigidity)
        println("  Modified Quaternion: q' = ($(q_modified.w), $(q_modified.x), $(q_modified.y), $(q_modified.z))")
        
        # VERIFICATION 2: Assert it's still a unit quaternion
        @test is_unit_quaternion(q_modified, 1e-6)
        println("  ✓ VERIFIED: Modified quaternion is also a unit quaternion")
        
        # VERIFICATION 3: Demonstrate predictable, significant change
        # Compute difference in quaternion components
        delta_w = abs(q_modified.w - q_initial.w)
        delta_x = abs(q_modified.x - q_initial.x)
        delta_y = abs(q_modified.y - q_initial.y)
        delta_z = abs(q_modified.z - q_initial.z)
        
        println("\n  Quaternion Component Changes:")
        println("    Δw = $(round(delta_w, digits=4))")
        println("    Δx = $(round(delta_x, digits=4))")
        println("    Δy = $(round(delta_y, digits=4))")
        println("    Δz = $(round(delta_z, digits=4))")
        
        # Fluidity primarily affects x and y components
        @test delta_x > 0.01  # Significant change in x
        @test delta_y > 0.01  # Significant change in y
        
        # The quaternion should be measurably different
        @test q_modified != q_initial
        
        # Compute angular distance between quaternions
        using .QuaternionMath: quaternion_distance
        angular_distance = quaternion_distance(q_initial, q_modified)
        println("  Angular distance: $(round(angular_distance, digits=4)) radians")
        @test angular_distance > 0.0
        
        println("\n  ✓ VERIFIED: Increasing Fluidity causes predictable, significant change")
        println("  ✓ Quaternion Frame Manager can be driven by game's core data")
        println("  " * "="^60)
    end
    
    @testset "Sparse Vector to Quaternion Translation" begin
        # Test direct translation from sparse vector format
        # Indices: 1=fluidity, 2=mass, 3=rigidity, 4=energy
        indices = [1, 2, 3, 4]
        values = [0.7, 1.2, 0.6, 1.0]
        
        q = from_sparse_vector(indices, values)
        
        # Should be a unit quaternion
        @test is_unit_quaternion(q)
        
        # Test with partial sparse vector (missing some attributes)
        indices_partial = [1, 2]
        values_partial = [0.8, 1.5]
        
        q_partial = from_sparse_vector(indices_partial, values_partial)
        @test is_unit_quaternion(q_partial)
        
        println("  ✓ Verified: Sparse vector translation produces unit quaternions")
    end
    
    @testset "Attribute Changes Produce Predictable Quaternion Changes" begin
        # Test that each attribute affects the quaternion predictably
        base_fluidity = 0.5
        base_mass = 1.0
        base_rigidity = 0.5
        
        q_base = attribute_to_quaternion(base_fluidity, base_mass, base_rigidity)
        
        # Increase fluidity
        q_high_fluidity = attribute_to_quaternion(base_fluidity + 0.3, base_mass, base_rigidity)
        # Fluidity should primarily affect x and y
        @test abs(q_high_fluidity.x) > abs(q_base.x)
        @test abs(q_high_fluidity.y) > abs(q_base.y)
        
        # Increase mass
        q_high_mass = attribute_to_quaternion(base_fluidity, base_mass + 0.5, base_rigidity)
        # Mass should primarily affect w
        @test abs(q_high_mass.w) > abs(q_base.w)
        
        # Increase rigidity
        q_high_rigidity = attribute_to_quaternion(base_fluidity, base_mass, base_rigidity + 0.3)
        # Rigidity should primarily affect z
        @test abs(q_high_rigidity.z) > abs(q_base.z)
        
        println("  ✓ Verified: Each attribute affects quaternion components predictably")
    end
    
    @testset "Quaternion Operations" begin
        q1 = normalize_quaternion(Quaternion(1.0, 1.0, 0.0, 0.0))
        q2 = normalize_quaternion(Quaternion(1.0, 0.0, 1.0, 0.0))
        
        # Test multiplication
        q_mult = quaternion_multiply(q1, q2)
        @test q_mult isa Quaternion
        
        # Test conjugate
        q_conj = quaternion_conjugate(q1)
        @test q_conj.w == q1.w
        @test q_conj.x == -q1.x
        @test q_conj.y == -q1.y
        @test q_conj.z == -q1.z
        
        # For unit quaternion, q * q^(-1) should be identity
        q_inv_mult = quaternion_multiply(q1, q_conj)
        @test abs(q_inv_mult.w - 1.0) < 0.01
    end
    
    @testset "Vector Rotation" begin
        # Test rotating a vector using a quaternion
        v = [1.0, 0.0, 0.0]
        
        # 90-degree rotation around z-axis
        q = from_euler_angles(0.0, 0.0, π/2)
        v_rotated = rotate_vector(v, q)
        
        # Should rotate to approximately [0, 1, 0]
        @test v_rotated[1] ≈ 0.0 atol=1e-10
        @test v_rotated[2] ≈ 1.0 atol=1e-10
        @test v_rotated[3] ≈ 0.0 atol=1e-10
    end
    
    @testset "Rotation Matrix Conversion" begin
        q = from_euler_angles(0.0, 0.0, π/2)
        matrix = to_rotation_matrix(q)
        
        # Should be 3x3
        @test size(matrix) == (3, 3)
        
        # Should be orthogonal (R^T * R = I)
        identity_approx = matrix' * matrix
        @test identity_approx ≈ I(3) atol=1e-10
        
        # Determinant should be 1
        @test det(matrix) ≈ 1.0 atol=1e-10
    end
    
    @testset "Euler Angle Conversion" begin
        # Test round-trip conversion
        roll, pitch, yaw = π/6, π/4, π/3
        
        q = from_euler_angles(roll, pitch, yaw)
        roll2, pitch2, yaw2 = to_euler_angles(q)
        
        # Should be approximately equal
        @test roll ≈ roll2 atol=1e-10
        @test pitch ≈ pitch2 atol=1e-10
        @test yaw ≈ yaw2 atol=1e-10
    end
    
    @testset "SLERP Interpolation" begin
        q1 = Quaternion(1.0, 0.0, 0.0, 0.0)
        q2 = from_euler_angles(0.0, 0.0, π/2)
        
        # Interpolate at t=0 should give q1
        q_start = slerp(q1, q2, 0.0)
        @test q_start.w ≈ q1.w atol=1e-10
        
        # Interpolate at t=1 should give q2
        q_end = slerp(q1, q2, 1.0)
        @test q_end.w ≈ q2.w atol=1e-10
        
        # Intermediate interpolation
        q_mid = slerp(q1, q2, 0.5)
        @test is_unit_quaternion(q_mid)
        
        println("  ✓ Verified: SLERP interpolation produces valid unit quaternions")
    end
    
    @testset "Integration: Full Attribute Evolution Pipeline" begin
        println("\n  Full Pipeline Test:")
        
        # Simulate evolution of a Spirit's attributes
        initial_state = [
            (1, 0.5),  # fluidity
            (2, 1.0),  # mass
            (3, 0.5),  # rigidity
            (4, 1.0)   # energy
        ]
        
        # Convert to quaternion
        indices = [idx for (idx, _) in initial_state]
        values = [val for (_, val) in initial_state]
        q1 = from_sparse_vector(indices, values)
        
        @test is_unit_quaternion(q1)
        println("    Initial state → Quaternion: ✓")
        
        # Evolve attributes (increase fluidity)
        evolved_state = [
            (1, 0.8),  # fluidity increased
            (2, 1.0),  # mass unchanged
            (3, 0.5),  # rigidity unchanged
            (4, 1.0)   # energy unchanged
        ]
        
        values2 = [val for (_, val) in evolved_state]
        q2 = from_sparse_vector(indices, values2)
        
        @test is_unit_quaternion(q2)
        println("    Evolved state → Quaternion: ✓")
        
        # Verify quaternions are different
        @test q1 != q2
        
        # Compute rotation matrix for rendering
        rotation_matrix = to_rotation_matrix(q2)
        @test size(rotation_matrix) == (3, 3)
        println("    Quaternion → Rotation Matrix: ✓")
        
        # Can interpolate between states
        q_interpolated = slerp(q1, q2, 0.5)
        @test is_unit_quaternion(q_interpolated)
        println("    Smooth interpolation: ✓")
        
        println("  ✓ Full pipeline: Attributes → Quaternion → Rendering works correctly")
    end
    
    @testset "Quaternion Stability Under Small Changes" begin
        # Small attribute changes should produce small quaternion changes
        q1 = attribute_to_quaternion(0.5, 1.0, 0.5)
        q2 = attribute_to_quaternion(0.500001, 1.0, 0.5)  # Tiny change
        
        dist = quaternion_distance(q1, q2)
        @test dist < 0.001  # Very small angular distance
        
        println("  ✓ Verified: Small attribute changes produce stable quaternion changes")
    end
    
    @testset "Zero and Extreme Attribute Values" begin
        # Test with zero attributes
        q_zero = attribute_to_quaternion(0.0, 0.0, 0.0, 1.0)
        @test is_unit_quaternion(q_zero)
        
        # Test with large attributes
        q_large = attribute_to_quaternion(10.0, 10.0, 10.0, 1.0)
        @test is_unit_quaternion(q_large)
        
        println("  ✓ Verified: Handles zero and extreme attribute values")
    end
    
end

println("\n✓ All Quaternion State Translation Tests Passed!")
println("  Proved: Sparse vectors can be translated to valid unit quaternions")
println("  Proved: Attribute changes produce predictable quaternion changes")
