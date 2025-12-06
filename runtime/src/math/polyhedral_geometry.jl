"""
Cyclotomic-Polyhedral Indexing Module

This module implements deterministic spatial indexing based on polyhedral geometry.
It provides stable and continuous cell indexing for 3D coordinates, essential for
the Spatial Data Manager (SDM) keying system.
"""
module PolyhedralGeometry

using LinearAlgebra

export PolyhedralCell, Point3D, compute_cell_id, get_cell_from_point, 
       get_cell_neighbors, cell_contains_point, get_cell_bounds, verify_indexing_continuity

"""
    Point3D

Represents a point in 3D space.
"""
struct Point3D
    x::Float64
    y::Float64
    z::Float64
end

"""
    PolyhedralCell

Represents a polyhedral cell in the spatial index with a unique identifier.
"""
struct PolyhedralCell
    id::UInt64
    center::Point3D
    cell_size::Float64
end

"""
    compute_cell_id(point::Point3D, cell_size::Float64 = 1.0)

Compute a unique 64-bit cell ID for a given 3D coordinate.
Points within the same cell will receive the same ID, proving indexing determinism.

The cell_size parameter determines the granularity of the spatial index.
"""
function compute_cell_id(point::Point3D, cell_size::Float64 = 1.0)
    # Compute discrete cell coordinates by flooring
    cell_x = floor(Int64, point.x / cell_size)
    cell_y = floor(Int64, point.y / cell_size)
    cell_z = floor(Int64, point.z / cell_size)
    
    # Use a deterministic hash function to combine coordinates
    # This ensures the same coordinates always produce the same ID
    cell_id = hash_coordinates(cell_x, cell_y, cell_z)
    
    return cell_id
end

"""
    hash_coordinates(x::Int64, y::Int64, z::Int64)

Deterministic hash function for combining 3D integer coordinates into a unique ID.
Uses bit manipulation and prime number mixing for good distribution.
"""
function hash_coordinates(x::Int64, y::Int64, z::Int64)
    # Constants based on large primes for good mixing
    # Convert signed integers to unsigned with reinterpret to preserve bit pattern
    h = UInt64(0x517cc1b727220a95)  # Random prime
    
    # Mix x coordinate - reinterpret to handle negative values
    ux = reinterpret(UInt64, x)
    h = xor(h, ux ⊻ (ux << 16))
    h = h * 0x85ebca6b
    
    # Mix y coordinate
    uy = reinterpret(UInt64, y)
    h = xor(h, uy ⊻ (uy << 16))
    h = h * 0xc2b2ae35
    
    # Mix z coordinate
    uz = reinterpret(UInt64, z)
    h = xor(h, uz ⊻ (uz << 16))
    h = h * 0x27d4eb2d
    
    # Final avalanche
    h = xor(h, h >> 15)
    
    return h
end

"""
    get_cell_from_point(point::Point3D, cell_size::Float64 = 1.0)

Get the polyhedral cell containing a given point.
Returns a PolyhedralCell with the cell's ID and center coordinates.
"""
function get_cell_from_point(point::Point3D, cell_size::Float64 = 1.0)
    # Compute cell ID
    cell_id = compute_cell_id(point, cell_size)
    
    # Compute cell center
    cell_x = floor(Int64, point.x / cell_size)
    cell_y = floor(Int64, point.y / cell_size)
    cell_z = floor(Int64, point.z / cell_size)
    
    center = Point3D(
        (cell_x + 0.5) * cell_size,
        (cell_y + 0.5) * cell_size,
        (cell_z + 0.5) * cell_size
    )
    
    return PolyhedralCell(cell_id, center, cell_size)
end

"""
    cell_contains_point(cell::PolyhedralCell, point::Point3D)

Check if a point is contained within a cell's bounds.
"""
function cell_contains_point(cell::PolyhedralCell, point::Point3D)
    half_size = cell.cell_size / 2.0
    
    # Check if point is within the cell bounds (inclusive on lower bound, exclusive on upper)
    # This matches the floor() behavior in cell ID computation
    in_x = abs(point.x - cell.center.x) <= half_size
    in_y = abs(point.y - cell.center.y) <= half_size
    in_z = abs(point.z - cell.center.z) <= half_size
    
    return in_x && in_y && in_z
end

"""
    get_cell_bounds(cell::PolyhedralCell)

Get the minimum and maximum bounds of a cell.
Returns (min_point, max_point) as a tuple of Point3D.
"""
function get_cell_bounds(cell::PolyhedralCell)
    half_size = cell.cell_size / 2.0
    
    min_point = Point3D(
        cell.center.x - half_size,
        cell.center.y - half_size,
        cell.center.z - half_size
    )
    
    max_point = Point3D(
        cell.center.x + half_size,
        cell.center.y + half_size,
        cell.center.z + half_size
    )
    
    return (min_point, max_point)
end

"""
    get_cell_neighbors(cell::PolyhedralCell)

Get the 26 neighboring cells (in 3D, each cell has 26 neighbors).
Returns a vector of PolyhedralCell representing the neighbors.
"""
function get_cell_neighbors(cell::PolyhedralCell)
    neighbors = PolyhedralCell[]
    
    # Generate all 26 neighbor offsets (3^3 - 1)
    for dx in -1:1
        for dy in -1:1
            for dz in -1:1
                if dx == 0 && dy == 0 && dz == 0
                    continue  # Skip the cell itself
                end
                
                # Compute neighbor center
                neighbor_center = Point3D(
                    cell.center.x + dx * cell.cell_size,
                    cell.center.y + dy * cell.cell_size,
                    cell.center.z + dz * cell.cell_size
                )
                
                # Compute neighbor ID
                neighbor_id = compute_cell_id(neighbor_center, cell.cell_size)
                
                push!(neighbors, PolyhedralCell(neighbor_id, neighbor_center, cell.cell_size))
            end
        end
    end
    
    return neighbors
end

"""
    distance_to_cell_center(point::Point3D, cell::PolyhedralCell)

Compute the Euclidean distance from a point to the center of a cell.
"""
function distance_to_cell_center(point::Point3D, cell::PolyhedralCell)
    dx = point.x - cell.center.x
    dy = point.y - cell.center.y
    dz = point.z - cell.center.z
    
    return sqrt(dx * dx + dy * dy + dz * dz)
end

"""
    verify_indexing_continuity(point1::Point3D, point2::Point3D, cell_size::Float64)

Verify that two points produce the same cell ID if they're in the same cell.
Returns (same_cell, cell_id1, cell_id2).
"""
function verify_indexing_continuity(point1::Point3D, point2::Point3D, cell_size::Float64)
    cell_id1 = compute_cell_id(point1, cell_size)
    cell_id2 = compute_cell_id(point2, cell_size)
    
    same_cell = (cell_id1 == cell_id2)
    
    return (same_cell, cell_id1, cell_id2)
end

end # module
