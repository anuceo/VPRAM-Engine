"""
Quaternion Mathematics Module

This module implements quaternion operations for translating sparse vector representations
into rotation/orientation states for visual rendering. It ensures that game state attributes
(Fluidity, Mass, Rigidity) are properly mapped to quaternion components for the rendering engine.
"""
module QuaternionMath

using LinearAlgebra

export Quaternion, from_sparse_vector, normalize_quaternion, is_unit_quaternion,
       quaternion_multiply, quaternion_conjugate, rotate_vector, to_rotation_matrix,
       from_euler_angles, to_euler_angles, slerp, attribute_to_quaternion

"""
    Quaternion

Represents a quaternion with components w, x, y, z.
Quaternions are used for representing rotations and orientations in 3D space.
"""
struct Quaternion
    w::Float64
    x::Float64
    y::Float64
    z::Float64
end

"""
    normalize_quaternion(q::Quaternion)

Normalize a quaternion to unit length.
Returns a new Quaternion with ||q|| = 1.
"""
function normalize_quaternion(q::Quaternion)
    norm = sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z)
    
    if norm < 1e-10
        # Return identity quaternion if norm is too small
        return Quaternion(1.0, 0.0, 0.0, 0.0)
    end
    
    return Quaternion(q.w / norm, q.x / norm, q.y / norm, q.z / norm)
end

"""
    is_unit_quaternion(q::Quaternion, tolerance::Float64 = 1e-6)

Check if a quaternion is a unit quaternion (norm ≈ 1).
"""
function is_unit_quaternion(q::Quaternion, tolerance::Float64 = 1e-6)
    norm_squared = q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z
    return abs(norm_squared - 1.0) < tolerance
end

"""
    attribute_to_quaternion(fluidity::Float64, mass::Float64, rigidity::Float64, 
                           energy::Float64 = 1.0)

Map sparse vector attributes to quaternion components.
This is the core function that translates game state to visual representation.

- fluidity: affects rotation freedom (maps to x, y components)
- mass: affects inertia (maps to w component)  
- rigidity: affects structural stability (maps to z component)
- energy: overall scaling factor

The mapping ensures predictable changes in quaternion based on attribute changes.
"""
function attribute_to_quaternion(fluidity::Float64, mass::Float64, rigidity::Float64,
                                 energy::Float64 = 1.0)
    # Map attributes to quaternion components with physical interpretation
    # Higher fluidity -> more rotation in x-y plane
    # Higher mass -> stronger w component (less rotation)
    # Higher rigidity -> more z-axis alignment
    
    # Scale attributes to reasonable ranges
    w = (1.0 + mass * 0.5) * energy
    x = fluidity * 0.7 * energy
    y = fluidity * 0.5 * energy  # Slightly less than x for asymmetry
    z = rigidity * 0.6 * energy
    
    # Create and normalize the quaternion
    q = Quaternion(w, x, y, z)
    return normalize_quaternion(q)
end

"""
    from_sparse_vector(indices::Vector{Int}, values::Vector{Float64})

Create a quaternion from a sparse vector representation.
Expects indices to represent: [1=fluidity, 2=mass, 3=rigidity, 4=energy, ...]
"""
function from_sparse_vector(indices::Vector{Int}, values::Vector{Float64})
    # Extract attributes from sparse vector
    # Default values if not present
    fluidity = 0.5
    mass = 1.0
    rigidity = 0.5
    energy = 1.0
    
    for (idx, val) in zip(indices, values)
        if idx == 1
            fluidity = val
        elseif idx == 2
            mass = val
        elseif idx == 3
            rigidity = val
        elseif idx == 4
            energy = val
        end
    end
    
    return attribute_to_quaternion(fluidity, mass, rigidity, energy)
end

"""
    quaternion_multiply(q1::Quaternion, q2::Quaternion)

Multiply two quaternions (Hamilton product).
Used for combining rotations.
"""
function quaternion_multiply(q1::Quaternion, q2::Quaternion)
    w = q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
    x = q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y
    y = q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x
    z = q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w
    
    return Quaternion(w, x, y, z)
end

"""
    quaternion_conjugate(q::Quaternion)

Compute the conjugate of a quaternion.
For unit quaternions, this is equivalent to the inverse.
"""
function quaternion_conjugate(q::Quaternion)
    return Quaternion(q.w, -q.x, -q.y, -q.z)
end

"""
    rotate_vector(v::Vector{Float64}, q::Quaternion)

Rotate a 3D vector using a quaternion.
The vector should have length 3.
"""
function rotate_vector(v::Vector{Float64}, q::Quaternion)
    @assert length(v) == 3 "Vector must be 3-dimensional"
    
    # Convert vector to quaternion (w=0)
    v_quat = Quaternion(0.0, v[1], v[2], v[3])
    
    # Rotate: q * v * q^(-1)
    q_conj = quaternion_conjugate(q)
    result = quaternion_multiply(quaternion_multiply(q, v_quat), q_conj)
    
    return [result.x, result.y, result.z]
end

"""
    to_rotation_matrix(q::Quaternion)

Convert a quaternion to a 3x3 rotation matrix.
"""
function to_rotation_matrix(q::Quaternion)
    # Ensure unit quaternion
    q = normalize_quaternion(q)
    
    w, x, y, z = q.w, q.x, q.y, q.z
    
    # Compute rotation matrix elements
    matrix = [
        1 - 2*(y*y + z*z)    2*(x*y - w*z)      2*(x*z + w*y);
        2*(x*y + w*z)        1 - 2*(x*x + z*z)  2*(y*z - w*x);
        2*(x*z - w*y)        2*(y*z + w*x)      1 - 2*(x*x + y*y)
    ]
    
    return matrix
end

"""
    from_euler_angles(roll::Float64, pitch::Float64, yaw::Float64)

Create a quaternion from Euler angles (in radians).
Convention: ZYX rotation order (yaw-pitch-roll).
"""
function from_euler_angles(roll::Float64, pitch::Float64, yaw::Float64)
    # Compute half angles
    cr = cos(roll * 0.5)
    sr = sin(roll * 0.5)
    cp = cos(pitch * 0.5)
    sp = sin(pitch * 0.5)
    cy = cos(yaw * 0.5)
    sy = sin(yaw * 0.5)
    
    # Compute quaternion components
    w = cr * cp * cy + sr * sp * sy
    x = sr * cp * cy - cr * sp * sy
    y = cr * sp * cy + sr * cp * sy
    z = cr * cp * sy - sr * sp * cy
    
    return Quaternion(w, x, y, z)
end

"""
    to_euler_angles(q::Quaternion)

Convert a quaternion to Euler angles (roll, pitch, yaw) in radians.
Returns a tuple (roll, pitch, yaw).
"""
function to_euler_angles(q::Quaternion)
    w, x, y, z = q.w, q.x, q.y, q.z
    
    # Roll (x-axis rotation)
    sinr_cosp = 2.0 * (w * x + y * z)
    cosr_cosp = 1.0 - 2.0 * (x * x + y * y)
    roll = atan(sinr_cosp, cosr_cosp)
    
    # Pitch (y-axis rotation)
    sinp = 2.0 * (w * y - z * x)
    if abs(sinp) >= 1
        pitch = copysign(π / 2, sinp)  # Use ±90° if out of range
    else
        pitch = asin(sinp)
    end
    
    # Yaw (z-axis rotation)
    siny_cosp = 2.0 * (w * z + x * y)
    cosy_cosp = 1.0 - 2.0 * (y * y + z * z)
    yaw = atan(siny_cosp, cosy_cosp)
    
    return (roll, pitch, yaw)
end

"""
    slerp(q1::Quaternion, q2::Quaternion, t::Float64)

Spherical linear interpolation between two quaternions.
t should be in [0, 1] where 0 returns q1 and 1 returns q2.
"""
function slerp(q1::Quaternion, q2::Quaternion, t::Float64)
    # Clamp t to [0, 1]
    t = clamp(t, 0.0, 1.0)
    
    # Compute dot product
    dot = q1.w * q2.w + q1.x * q2.x + q1.y * q2.y + q1.z * q2.z
    
    # If quaternions are very close, use linear interpolation
    if abs(dot) > 0.9995
        result = Quaternion(
            q1.w + t * (q2.w - q1.w),
            q1.x + t * (q2.x - q1.x),
            q1.y + t * (q2.y - q1.y),
            q1.z + t * (q2.z - q1.z)
        )
        return normalize_quaternion(result)
    end
    
    # If dot product is negative, negate one quaternion to take shorter path
    q2_adjusted = dot < 0 ? Quaternion(-q2.w, -q2.x, -q2.y, -q2.z) : q2
    dot = abs(dot)
    
    # Compute angle between quaternions
    theta = acos(dot)
    sin_theta = sin(theta)
    
    # Compute interpolation weights
    w1 = sin((1.0 - t) * theta) / sin_theta
    w2 = sin(t * theta) / sin_theta
    
    result = Quaternion(
        w1 * q1.w + w2 * q2_adjusted.w,
        w1 * q1.x + w2 * q2_adjusted.x,
        w1 * q1.y + w2 * q2_adjusted.y,
        w1 * q1.z + w2 * q2_adjusted.z
    )
    
    return result
end

"""
    quaternion_distance(q1::Quaternion, q2::Quaternion)

Compute the angular distance between two quaternions.
Returns the angle in radians.
"""
function quaternion_distance(q1::Quaternion, q2::Quaternion)
    dot = abs(q1.w * q2.w + q1.x * q2.x + q1.y * q2.y + q1.z * q2.z)
    dot = clamp(dot, 0.0, 1.0)
    return acos(dot)
end

end # module
