"""
Tests for Cyclotomic-Polyhedral Indexing Determinism (Task 2)

These tests prove that the coordinate system is stable and deterministic,
crucial for the Spatial Data Manager (SDM) keying system.
"""

using Test

# Add the src directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, "../src"))

include("../src/math/polyhedral_geometry.jl")
using .PolyhedralGeometry

@testset "Cyclotomic-Polyhedral Indexing Determinism Tests" begin
    
    @testset "Basic Point and Cell Creation" begin
        p = Point3D(1.5, 2.7, 3.2)
        @test p.x == 1.5
        @test p.y == 2.7
        @test p.z == 3.2
        
        # Compute cell for point
        cell = get_cell_from_point(p, 1.0)
        @test cell.cell_size == 1.0
        @test cell.id isa UInt64
    end
    
    @testset "Task 2 Verification: Proximity Test (Main Requirement)" begin
        println("\n  Task 2 Core Verification:")
        println("  " * "="^60)
        
        # Test Point 1: Define an arbitrary 3D coordinate
        P1 = Point3D(10.5, 20.3, 30.7)
        println("  Test Point P1: ($(P1.x), $(P1.y), $(P1.z))")
        
        # Indexing: Generate unique Cell ID for P1
        cell_id_1 = compute_cell_id(P1, 1.0)
        println("  Cell ID for P1: $cell_id_1")
        
        # Test Point 2: Infinitesimally offset from P1 (within same cell)
        epsilon = 1e-6
        P2 = Point3D(P1.x + epsilon, P1.y + epsilon, P1.z + epsilon)
        println("  Test Point P2: ($(P2.x), $(P2.y), $(P2.z))")
        println("  Offset: $epsilon units")
        
        # Indexing: Generate Cell ID for P2
        cell_id_2 = compute_cell_id(P2, 1.0)
        println("  Cell ID for P2: $cell_id_2")
        
        # VERIFICATION: Assert both points map to the same Cell ID
        @test cell_id_1 == cell_id_2
        println("  ✓ VERIFIED: Both points map to EXACT SAME Cell ID")
        println("  ✓ Indexing is stable within cell boundaries")
        println("  " * "="^60)
    end
    
    @testset "Determinism: Same Point Always Returns Same ID" begin
        point = Point3D(5.123, 8.456, 12.789)
        
        # Compute ID multiple times
        ids = [compute_cell_id(point, 1.0) for _ in 1:100]
        
        # All IDs should be identical
        @test all(id == ids[1] for id in ids)
        @test length(unique(ids)) == 1
        
        println("  ✓ Verified: Same point produces identical ID 100 times")
    end
    
    @testset "Continuity Within Cell Boundaries" begin
        # Define a cell center point
        center = Point3D(10.5, 20.5, 30.5)  # Center of cell
        cell_id_center = compute_cell_id(center, 1.0)
        
        # Test multiple points within the same cell
        offsets = [
            (0.0, 0.0, 0.0),
            (0.1, 0.1, 0.1),
            (0.49, 0.49, 0.49),
            (-0.49, -0.49, -0.49),
            (0.3, -0.2, 0.4),
            (-0.4, 0.3, -0.1)
        ]
        
        for (dx, dy, dz) in offsets
            p = Point3D(center.x + dx, center.y + dy, center.z + dz)
            cell_id = compute_cell_id(p, 1.0)
            @test cell_id == cell_id_center
        end
        
        println("  ✓ Verified: $(length(offsets)) points within cell have same ID")
    end
    
    @testset "Discontinuity Across Cell Boundaries" begin
        # Points clearly on opposite sides of a cell boundary should have different IDs
        p1 = Point3D(9.9, 20.0, 30.0)
        p2 = Point3D(10.1, 20.0, 30.0)  # Clearly across X boundary
        
        cell_id_1 = compute_cell_id(p1, 1.0)
        cell_id_2 = compute_cell_id(p2, 1.0)
        
        @test cell_id_1 != cell_id_2
        
        println("  ✓ Verified: Points across boundary have different IDs")
    end
    
    @testset "Cell Properties and Bounds" begin
        point = Point3D(15.7, 25.2, 35.8)
        cell = get_cell_from_point(point, 1.0)
        
        # Verify cell contains the original point
        @test cell_contains_point(cell, point)
        
        # Get cell bounds
        min_p, max_p = get_cell_bounds(cell)
        
        # Verify bounds are correct
        @test max_p.x - min_p.x ≈ 1.0
        @test max_p.y - min_p.y ≈ 1.0
        @test max_p.z - min_p.z ≈ 1.0
        
        # Verify point is within bounds
        @test point.x >= min_p.x && point.x <= max_p.x
        @test point.y >= min_p.y && point.y <= max_p.y
        @test point.z >= min_p.z && point.z <= max_p.z
    end
    
    @testset "Different Cell Sizes" begin
        # Test with different cell sizes
        for cell_size in [0.1, 0.5, 1.0, 2.0, 10.0]
            # Use a point well within a cell (at 0.25 offset from floor)
            point = Point3D(7.25 * cell_size, 8.25 * cell_size, 9.25 * cell_size)
            cell = get_cell_from_point(point, cell_size)
            @test cell.cell_size == cell_size
            
            # Verify nearby points (well within cell) have same ID
            # Use very small offset to ensure we stay in same cell
            nearby = Point3D(point.x + cell_size * 0.01, 
                           point.y + cell_size * 0.01, 
                           point.z + cell_size * 0.01)
            @test compute_cell_id(point, cell_size) == compute_cell_id(nearby, cell_size)
        end
        
        println("  ✓ Verified: Indexing works correctly for 5 different cell sizes")
    end
    
    @testset "Neighbor Cell Generation" begin
        point = Point3D(0.5, 0.5, 0.5)
        cell = get_cell_from_point(point, 1.0)
        
        neighbors = get_cell_neighbors(cell)
        
        # Should have exactly 26 neighbors (3^3 - 1)
        @test length(neighbors) == 26
        
        # All neighbors should have different IDs
        neighbor_ids = [n.id for n in neighbors]
        @test length(unique(neighbor_ids)) == 26
        
        # No neighbor should have the same ID as the center cell
        @test !(cell.id in neighbor_ids)
        
        println("  ✓ Verified: Cell has exactly 26 unique neighbors")
    end
    
    @testset "Indexing Continuity Verification Function" begin
        # Test the built-in verification function
        p1 = Point3D(5.2, 10.3, 15.4)
        p2 = Point3D(5.2001, 10.3001, 15.4001)  # Very close
        
        same_cell, id1, id2 = verify_indexing_continuity(p1, p2, 1.0)
        
        @test same_cell == true
        @test id1 == id2
        
        # Test clearly across boundary
        p3 = Point3D(5.3, 10.0, 15.0)
        p4 = Point3D(6.3, 10.0, 15.0)  # Definitely different cell
        
        different_cell, id3, id4 = verify_indexing_continuity(p3, p4, 1.0)
        
        @test different_cell == false
        @test id3 != id4
    end
    
    @testset "Negative Coordinates" begin
        # Test that indexing works correctly with negative coordinates
        points = [
            Point3D(-5.5, -10.3, -15.7),
            Point3D(-5.51, -10.31, -15.71),  # Very close, same cell
            Point3D(0.3, 0.3, 0.3),
            Point3D(0.31, 0.31, 0.31)  # Very close, same cell
        ]
        
        # Nearby negative points should have same ID
        id1 = compute_cell_id(points[1], 1.0)
        id2 = compute_cell_id(points[2], 1.0)
        @test id1 == id2
        
        # Points around origin (both positive and in same cell)
        id3 = compute_cell_id(points[3], 1.0)
        id4 = compute_cell_id(points[4], 1.0)
        @test id3 == id4
        
        println("  ✓ Verified: Indexing handles negative coordinates correctly")
    end
    
    @testset "Large Coordinate Values" begin
        # Test with very large coordinates
        large_point1 = Point3D(1000000.5, 2000000.3, 3000000.7)
        large_point2 = Point3D(1000000.5001, 2000000.3001, 3000000.7001)
        
        id1 = compute_cell_id(large_point1, 1.0)
        id2 = compute_cell_id(large_point2, 1.0)
        
        @test id1 == id2
        
        println("  ✓ Verified: Indexing works with large coordinate values")
    end
    
    @testset "Hash Function Uniqueness" begin
        # Generate many different cell IDs and verify they're mostly unique
        cell_ids = Set{UInt64}()
        
        for x in 0:19
            for y in 0:19
                for z in 0:19
                    p = Point3D(Float64(x), Float64(y), Float64(z))
                    push!(cell_ids, compute_cell_id(p, 1.0))
                end
            end
        end
        
        # Should have 20^3 = 8000 unique IDs
        @test length(cell_ids) == 8000
        
        println("  ✓ Verified: Hash function produces 8000 unique IDs for 8000 cells")
    end
    
end

println("\n✓ All Cyclotomic-Polyhedral Indexing Tests Passed!")
println("  Proved: Indexing is stable and deterministic within cell boundaries")
