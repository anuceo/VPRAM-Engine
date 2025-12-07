# VPRAM Runtime - Main module file
module VPRAMRuntime

using SparseArrays
using LinearAlgebra
using Random
using Statistics

# Include all submodules
include("kernels/transformation.jl")
include("math/brownian_motion.jl")
include("math/polyhedral_geometry.jl")
include("math/quaternion_math.jl")

# Export main types and functions from transformation
export SparseVector, KernelFunction
export identity_kernel, scale_kernel, shift_kernel, merge_kernel, filter_kernel
export apply_kernel, get_indices, get_values, get_size

# Export from brownian_motion
export apply_brownian, apply_brownian_kernel

# Export from polyhedral_geometry
export Point3D, compute_cell_id

# Export from quaternion_math
export attribute_to_quaternion, normalize_quaternion, quaternion_to_rotation_matrix

end # module VPRAMRuntime
