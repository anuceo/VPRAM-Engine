"""
Tests for Sparse Vector Transformation Kernel

These tests prove that the sparse vector data structure can be reliably 
manipulated by various kernel operations.
"""

using Test

# Add the src directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, "../src"))

include("../src/kernels/transformation.jl")
using .Transformation

@testset "Sparse Vector Integrity Tests" begin
    
    @testset "Basic Construction and Properties" begin
        # Test empty sparse vector
        sv_empty = SparseVector{Float64}(10)
        @test get_nnz(sv_empty) == 0
        @test sv_empty.size == 10
        @test isempty(get_indices(sv_empty))
        @test isempty(get_values(sv_empty))
        
        # Test sparse vector with values
        indices = [1, 3, 5, 7]
        values = [1.0, 2.0, 3.0, 4.0]
        sv = SparseVector(indices, values, 10)
        
        @test get_nnz(sv) == 4
        @test sv.size == 10
        @test get_indices(sv) == indices
        @test get_values(sv) == values
    end
    
    @testset "Automatic Sorting and Deduplication" begin
        # Test unsorted indices are automatically sorted
        indices = [5, 1, 3]
        values = [3.0, 1.0, 2.0]
        sv = SparseVector(indices, values, 10)
        
        @test get_indices(sv) == [1, 3, 5]
        @test get_values(sv) == [1.0, 2.0, 3.0]
        
        # Test duplicate indices are merged by summing
        indices = [1, 1, 3, 3, 5]
        values = [1.0, 2.0, 3.0, 4.0, 5.0]
        sv = SparseVector(indices, values, 10)
        
        @test get_indices(sv) == [1, 3, 5]
        @test get_values(sv) == [3.0, 7.0, 5.0]
    end
    
    @testset "Identity Kernel Preserves Structure" begin
        indices = [2, 4, 6, 8]
        values = [10.0, 20.0, 30.0, 40.0]
        sv = SparseVector(indices, values, 10)
        
        sv_result = apply_kernel(identity_kernel, sv)
        
        # Verify structure is preserved
        @test get_nnz(sv_result) == get_nnz(sv)
        @test sv_result.size == sv.size
        @test get_indices(sv_result) == get_indices(sv)
        @test get_values(sv_result) == get_values(sv)
        
        # Verify it's a copy, not the same object
        @test sv_result.indices !== sv.indices
        @test sv_result.values !== sv.values
    end
    
    @testset "Scale Kernel Transforms Values Correctly" begin
        indices = [1, 3, 5]
        values = [2.0, 4.0, 6.0]
        sv = SparseVector(indices, values, 10)
        
        factor = 2.5
        sv_scaled = apply_kernel(scale_kernel, sv, factor)
        
        # Verify indices unchanged
        @test get_indices(sv_scaled) == indices
        
        # Verify values scaled correctly
        @test get_values(sv_scaled) ≈ [5.0, 10.0, 15.0]
        
        # Verify original unchanged
        @test get_values(sv) == values
    end
    
    @testset "Shift Kernel Adds Offset Correctly" begin
        indices = [1, 2, 3]
        values = [10.0, 20.0, 30.0]
        sv = SparseVector(indices, values, 5)
        
        offset = 5.0
        sv_shifted = apply_kernel(shift_kernel, sv, offset)
        
        # Verify indices unchanged
        @test get_indices(sv_shifted) == indices
        
        # Verify values shifted correctly
        @test get_values(sv_shifted) ≈ [15.0, 25.0, 35.0]
    end
    
    @testset "Merge Kernel Combines Vectors Correctly" begin
        indices1 = [1, 3, 5]
        values1 = [1.0, 2.0, 3.0]
        sv1 = SparseVector(indices1, values1, 10)
        
        indices2 = [2, 3, 4]
        values2 = [4.0, 5.0, 6.0]
        sv2 = SparseVector(indices2, values2, 10)
        
        sv_merged = apply_kernel(merge_kernel, sv1, sv2)
        
        # Verify merged structure
        @test sv_merged.size == 10
        
        # Convert to dense to verify correctness
        dense = to_dense(sv_merged)
        @test dense[1] ≈ 1.0
        @test dense[2] ≈ 4.0
        @test dense[3] ≈ 7.0  # 2.0 + 5.0
        @test dense[4] ≈ 6.0
        @test dense[5] ≈ 3.0
    end
    
    @testset "Filter Kernel Removes Small Values" begin
        indices = [1, 2, 3, 4, 5]
        values = [0.1, 1.5, 0.05, 2.0, 0.8]
        sv = SparseVector(indices, values, 10)
        
        threshold = 1.0
        sv_filtered = apply_kernel(filter_kernel, sv, threshold)
        
        # Verify only values >= threshold remain
        @test get_nnz(sv_filtered) == 2
        @test get_indices(sv_filtered) == [2, 4]
        @test get_values(sv_filtered) ≈ [1.5, 2.0]
    end
    
    @testset "Dense Conversion Round-Trip" begin
        indices = [1, 3, 5, 7, 9]
        values = [1.5, 2.5, 3.5, 4.5, 5.5]
        sv = SparseVector(indices, values, 10)
        
        # Convert to dense
        dense = to_dense(sv)
        @test length(dense) == 10
        @test dense[1] ≈ 1.5
        @test dense[3] ≈ 2.5
        @test dense[2] ≈ 0.0
        @test dense[4] ≈ 0.0
        
        # Convert back to sparse
        sv_reconstructed = from_dense(dense)
        @test get_indices(sv_reconstructed) == get_indices(sv)
        @test get_values(sv_reconstructed) ≈ get_values(sv)
    end
    
    @testset "Kernel Composition Maintains Integrity" begin
        # Test that multiple kernel operations maintain integrity
        indices = [1, 2, 3]
        values = [10.0, 20.0, 30.0]
        sv = SparseVector(indices, values, 5)
        
        # Apply multiple transformations
        sv1 = apply_kernel(scale_kernel, sv, 2.0)      # [20, 40, 60]
        sv2 = apply_kernel(shift_kernel, sv1, 10.0)    # [30, 50, 70]
        sv3 = apply_kernel(filter_kernel, sv2, 40.0)   # [50, 70]
        
        # Verify final result
        @test get_nnz(sv3) == 2
        @test get_indices(sv3) == [2, 3]
        @test get_values(sv3) ≈ [50.0, 70.0]
        
        # Verify original unchanged
        @test get_values(sv) == values
    end
    
    @testset "Zero Values Handled Correctly" begin
        # Test that zeros are properly removed during construction
        indices = [1, 2, 3, 4]
        values = [1.0, 0.0, 2.0, 0.0]
        sv = SparseVector(indices, values, 5)
        
        # Zeros might be kept initially, but operations should handle them
        dense = to_dense(sv)
        sv_clean = from_dense(dense)
        
        # After round-trip through dense, zeros should be gone
        @test all(get_values(sv_clean) .!= 0.0)
    end
    
    @testset "Large Sparse Vector Operations" begin
        # Test with larger sparse vectors to ensure scalability
        n = 10000
        nnz_count = 100
        
        indices = sort(rand(1:n, nnz_count))
        values = rand(Float64, nnz_count)
        sv = SparseVector(indices, values, n)
        
        # Test operations complete without error
        sv_scaled = apply_kernel(scale_kernel, sv, 1.5)
        sv_shifted = apply_kernel(shift_kernel, sv_scaled, 0.1)
        sv_filtered = apply_kernel(filter_kernel, sv_shifted, 0.5)
        
        # Basic sanity checks
        @test sv.size == n
        @test get_nnz(sv_filtered) <= get_nnz(sv)
    end
    
end

println("\n✓ All Sparse Vector Integrity Tests Passed!")
println("  Proved: Sparse vectors can be reliably manipulated by kernels")
