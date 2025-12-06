"""
Sparse Vector Transformation Kernel

This module implements the core sparse vector data structure and transformation operations
for the VPRAM engine. It provides reliable manipulation of sparse vectors through various
kernel operations.
"""
module Transformation

using SparseArrays
using LinearAlgebra

export SparseVector, apply_kernel, identity_kernel, scale_kernel, shift_kernel, 
       merge_kernel, filter_kernel, get_nnz, get_values, get_indices

"""
    SparseVector

A sparse vector implementation optimized for VPRAM operations.
Stores only non-zero elements with their indices.
"""
struct SparseVector{T <: Number}
    indices::Vector{Int}
    values::Vector{T}
    size::Int
    
    function SparseVector{T}(indices::Vector{Int}, values::Vector{T}, size::Int) where T
        if !issorted(indices)
            perm = sortperm(indices)
            indices = indices[perm]
            values = values[perm]
        end
        
        # Remove duplicates by summing values at same index
        if length(indices) > 1
            unique_indices = Int[]
            unique_values = T[]
            current_idx = indices[1]
            current_val = values[1]
            
            for i in 2:length(indices)
                if indices[i] == current_idx
                    current_val += values[i]
                else
                    if current_val != 0
                        push!(unique_indices, current_idx)
                        push!(unique_values, current_val)
                    end
                    current_idx = indices[i]
                    current_val = values[i]
                end
            end
            
            # Add last element
            if current_val != 0
                push!(unique_indices, current_idx)
                push!(unique_values, current_val)
            end
            
            indices = unique_indices
            values = unique_values
        end
        
        new{T}(indices, values, size)
    end
end

# Convenience constructors
SparseVector(indices::Vector{Int}, values::Vector{T}, size::Int) where T = SparseVector{T}(indices, values, size)

function SparseVector{T}(size::Int) where T
    SparseVector{T}(Int[], T[], size)
end

"""
    get_nnz(sv::SparseVector)

Returns the number of non-zero elements in the sparse vector.
"""
get_nnz(sv::SparseVector) = length(sv.indices)

"""
    get_values(sv::SparseVector)

Returns the array of non-zero values.
"""
get_values(sv::SparseVector) = copy(sv.values)

"""
    get_indices(sv::SparseVector)

Returns the array of indices of non-zero values.
"""
get_indices(sv::SparseVector) = copy(sv.indices)

"""
    apply_kernel(kernel::Function, sv::SparseVector, args...)

Apply a kernel function to a sparse vector with additional arguments.
The kernel should return a new SparseVector.
"""
function apply_kernel(kernel::Function, sv::SparseVector, args...)
    return kernel(sv, args...)
end

"""
    identity_kernel(sv::SparseVector)

Identity kernel - returns a copy of the input sparse vector.
This proves the sparse vector structure can be reliably preserved.
"""
function identity_kernel(sv::SparseVector{T}) where T
    return SparseVector{T}(copy(sv.indices), copy(sv.values), sv.length)
end

"""
    scale_kernel(sv::SparseVector, factor::Number)

Scale kernel - multiplies all non-zero values by a factor.
This proves the sparse vector values can be reliably transformed.
"""
function scale_kernel(sv::SparseVector{T}, factor::Number) where T
    new_values = sv.values .* factor
    return SparseVector{T}(copy(sv.indices), new_values, sv.length)
end

"""
    shift_kernel(sv::SparseVector, offset::Number)

Shift kernel - adds an offset to all non-zero values.
This proves additive transformations work correctly on sparse vectors.
"""
function shift_kernel(sv::SparseVector{T}, offset::Number) where T
    new_values = sv.values .+ offset
    return SparseVector{T}(copy(sv.indices), new_values, sv.length)
end

"""
    merge_kernel(sv1::SparseVector, sv2::SparseVector)

Merge kernel - combines two sparse vectors by summing values at matching indices.
This proves the sparse vector structure can handle complex operations.
"""
function merge_kernel(sv1::SparseVector{T}, sv2::SparseVector{T}) where T
    @assert sv1.length == sv2.length "Sparse vectors must have same length"
    
    all_indices = vcat(sv1.indices, sv2.indices)
    all_values = vcat(sv1.values, sv2.values)
    
    return SparseVector{T}(all_indices, all_values, sv1.length)
end

"""
    filter_kernel(sv::SparseVector, threshold::Number)

Filter kernel - removes values below a threshold.
This proves the sparse vector can be selectively manipulated.
"""
function filter_kernel(sv::SparseVector{T}, threshold::Number) where T
    mask = abs.(sv.values) .>= threshold
    new_indices = sv.indices[mask]
    new_values = sv.values[mask]
    
    return SparseVector{T}(new_indices, new_values, sv.length)
end

"""
    to_dense(sv::SparseVector)

Convert sparse vector to dense array representation.
Useful for verification and testing.
"""
function to_dense(sv::SparseVector{T}) where T
    dense = zeros(T, sv.length)
    for (idx, val) in zip(sv.indices, sv.values)
        dense[idx] = val
    end
    return dense
end

"""
    from_dense(dense::Vector{T}) where T

Create a sparse vector from a dense array.
"""
function from_dense(dense::Vector{T}) where T
    indices = Int[]
    values = T[]
    
    for (i, val) in enumerate(dense)
        if val != 0
            push!(indices, i)
            push!(values, val)
        end
    end
    
    return SparseVector{T}(indices, values, length(dense))
end

end # module
