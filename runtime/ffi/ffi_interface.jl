"""
Julia FFI Interface for VPRAM Engine

This module provides a C-ABI compatible interface for calling Julia mathematical
functions from Rust using zero-copy FFI with jlrs.
"""

# Load the required modules
include("../src/kernels/transformation.jl")
include("../src/math/brownian_motion.jl")
include("../src/math/polyhedral_geometry.jl")
include("../src/math/quaternion_math.jl")

using .Transformation
using .BrownianMotion
using .PolyhedralGeometry
using .QuaternionMath

"""
C-compatible struct layouts matching Rust's #[repr(C)] definitions
"""

# Corresponds to Rust's SparseBuffer
struct SparseBuffer
    indices::Ptr{UInt32}
    values::Ptr{Float64}
    length::UInt32
    capacity::UInt32
end

# Corresponds to Rust's KernelResult
struct KernelResult
    cell_id::UInt64
    quaternion::NTuple{4, Float64}
    new_sv_length::UInt32
    error_code::Int32
end

"""
    run_vpram_kernel_ffi(input_buffer_ptr::Ptr{SparseBuffer}, 
                         output_result_ptr::Ptr{KernelResult},
                         position_x::Float64, position_y::Float64, position_z::Float64,
                         kernel_type::UInt32, kernel_param::Float64)::Cint

Main FFI entry point callable from Rust via C ABI.

This function:
1. Reads the sparse vector data from Rust-owned memory
2. Executes the requested VPRAM kernel transformation
3. Applies Brownian motion evolution
4. Computes Cell ID and Quaternion
5. Writes results back to Rust-owned memory

Parameters:
- input_buffer_ptr: Pointer to SparseBuffer (input/output)
- output_result_ptr: Pointer to KernelResult (output only)
- position_x, position_y, position_z: Entity's 3D position
- kernel_type: Type of kernel to apply (0=identity, 1=scale, 2=shift, etc.)
- kernel_param: Parameter for the kernel operation

Returns:
- 0 on success, non-zero error code on failure
"""
function run_vpram_kernel_ffi(
    input_buffer_ptr::Ptr{SparseBuffer},
    output_result_ptr::Ptr{KernelResult},
    position_x::Float64,
    position_y::Float64,
    position_z::Float64,
    kernel_type::UInt32,
    kernel_param::Float64
)::Cint
    try
        # Safety: Disable GC during pointer operations
        GC.@preserve input_buffer_ptr output_result_ptr begin
            # 1. READ: Convert raw pointer to Julia struct
            input_buffer = unsafe_load(input_buffer_ptr)
            
            # Validate buffer
            if input_buffer.length > input_buffer.capacity
                # Error: buffer overflow
                unsafe_store!(output_result_ptr, KernelResult(
                    0, (0.0, 0.0, 0.0, 0.0), 0, -1
                ))
                return Cint(-1)
            end
            
            # Convert to Julia arrays (no copy, just wraps the pointer)
            indices_array = unsafe_wrap(Array, input_buffer.indices, 
                                       Int(input_buffer.length), own=false)
            values_array = unsafe_wrap(Array, input_buffer.values, 
                                      Int(input_buffer.length), own=false)
            
            # Create Julia SparseVector from the input data
            # Convert indices from UInt32 to Int
            indices_int = Int[Int(idx) for idx in indices_array]
            sv = Transformation.SparseVector(indices_int, values_array, 
                                           Int(input_buffer.capacity))
            
            # 2. EXECUTE: Apply the requested kernel
            transformed_sv = if kernel_type == 0
                # Identity kernel
                Transformation.apply_kernel(Transformation.identity_kernel, sv)
            elseif kernel_type == 1
                # Scale kernel
                Transformation.apply_kernel(Transformation.scale_kernel, sv, kernel_param)
            elseif kernel_type == 2
                # Shift kernel
                Transformation.apply_kernel(Transformation.shift_kernel, sv, kernel_param)
            elseif kernel_type == 3
                # Filter kernel
                Transformation.apply_kernel(Transformation.filter_kernel, sv, abs(kernel_param))
            else
                # Unknown kernel type - return error
                unsafe_store!(output_result_ptr, KernelResult(
                    0, (0.0, 0.0, 0.0, 0.0), 0, -2
                ))
                return Cint(-2)
            end
            
            # 3. APPLY BROWNIAN MOTION: Add stochastic evolution
            # Use small time step and volatility for stability
            evolved_values = BrownianMotion.apply_brownian_kernel(
                Transformation.get_values(transformed_sv), 
                0.1,  # dt
                0.05  # volatility
            )
            
            # Create evolved sparse vector
            evolved_sv = Transformation.SparseVector(
                Transformation.get_indices(transformed_sv),
                evolved_values,
                transformed_sv.size
            )
            
            # 4. COMPUTE: Calculate Cell ID from position
            position = PolyhedralGeometry.Point3D(position_x, position_y, position_z)
            cell_id = PolyhedralGeometry.compute_cell_id(position, 1.0)
            
            # 5. COMPUTE: Calculate Quaternion from sparse vector attributes
            sv_indices = Transformation.get_indices(evolved_sv)
            sv_values = Transformation.get_values(evolved_sv)
            quaternion = QuaternionMath.from_sparse_vector(sv_indices, sv_values)
            
            # 6. WRITE: Update the input buffer with evolved sparse vector
            new_length = min(length(sv_values), Int(input_buffer.capacity))
            
            # Write back indices and values (convert Int back to UInt32)
            for i in 1:new_length
                unsafe_store!(input_buffer.indices, UInt32(sv_indices[i]), i)
                unsafe_store!(input_buffer.values, sv_values[i], i)
            end
            
            # 7. WRITE: Fill output result structure
            result = KernelResult(
                cell_id,
                (quaternion.w, quaternion.x, quaternion.y, quaternion.z),
                UInt32(new_length),
                Int32(0)  # Success
            )
            
            unsafe_store!(output_result_ptr, result)
            
            return Cint(0)  # Success
        end
    catch e
        # Error handling: log error and return failure code
        println(stderr, "FFI Error: ", e)
        try
            unsafe_store!(output_result_ptr, KernelResult(
                0, (0.0, 0.0, 0.0, 0.0), 0, -99
            ))
        catch
            # Failed to write error result
        end
        return Cint(-99)
    end
end

"""
    initialize_julia_runtime()::Cint

Initialize the Julia runtime for FFI usage.
This should be called once by Rust before any FFI calls.

Returns 0 on success.
"""
function initialize_julia_runtime()::Cint
    println("Julia runtime initialized for VPRAM FFI")
    return Cint(0)
end

"""
    cleanup_julia_runtime()::Cint

Cleanup Julia runtime resources.
This should be called once by Rust when shutting down.

Returns 0 on success.
"""
function cleanup_julia_runtime()::Cint
    println("Julia runtime cleanup for VPRAM FFI")
    return Cint(0)
end

# Precompile the main FFI function for better performance
precompile(run_vpram_kernel_ffi, (Ptr{SparseBuffer}, Ptr{KernelResult}, 
                                   Float64, Float64, Float64, UInt32, Float64))

println("VPRAM Julia FFI Interface loaded successfully")
