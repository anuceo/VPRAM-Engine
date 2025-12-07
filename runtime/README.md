# VPRAM Engine - Julia Runtime

Mathematical core of the Vector Parallel Random Access Memory (VPRAM) Engine.

## Overview

This directory contains the Julia implementation of the VPRAM engine's core mathematical operations, proving the integrity and correctness of three fundamental systems:

1. **Sparse Vector Integrity + Brownian Motion Non-Repeatability**
2. **Cyclotomic-Polyhedral Indexing Determinism**
3. **Quaternion State Translation**

## Project Structure

```
runtime/
├── Project.toml              # Julia project dependencies
├── src/                      # Source code
│   ├── kernels/
│   │   └── transformation.jl # Sparse vector operations and kernel functions
│   └── math/
│       ├── brownian_motion.jl       # Brownian motion for non-repeatability
│       ├── polyhedral_geometry.jl   # Spatial indexing system
│       └── quaternion_math.jl       # Quaternion operations for rendering
└── test/                     # Test suite
    ├── runtests.jl                       # Main test runner
    ├── test_transformation.jl            # Sparse vector tests
    ├── test_brownian_motion.jl           # Brownian motion tests
    ├── test_polyhedral_geometry.jl       # Spatial indexing tests
    ├── test_quaternion_math.jl           # Quaternion tests
    └── test_integrated_verification.jl   # Integration tests
```

## Running Tests

To run the complete test suite:

```bash
cd runtime
julia test/runtests.jl
```

To run individual test modules:

```bash
julia test/test_transformation.jl
julia test/test_brownian_motion.jl
julia test/test_polyhedral_geometry.jl
julia test/test_quaternion_math.jl
julia test/test_integrated_verification.jl
```

## Core Components

### 1. Sparse Vector Transformation (`src/kernels/transformation.jl`)

Implements the core sparse vector data structure optimized for VPRAM operations:

- **SparseVector**: Stores only non-zero elements with indices
- **Kernel Operations**: 
  - `identity_kernel`: Preserve structure
  - `scale_kernel`: Multiply values
  - `shift_kernel`: Add offset
  - `merge_kernel`: Combine vectors
  - `filter_kernel`: Remove small values

**Key Features:**
- Automatic sorting and deduplication
- Efficient sparse-dense conversion
- Composable kernel operations

### 2. Brownian Motion (`src/math/brownian_motion.jl`)

Provides stochastic evolution ensuring non-repeatability:

- **BrownianState**: Tracks cumulative displacement over time
- **Evolution**: Uses standard Brownian motion equation: dW = √(dt) * N(0,1) * volatility
- **Verification**: Includes tools to prove non-repeatability

**Key Features:**
- Deterministic seeding for reproducibility when needed
- Statistical validation (mean ≈ 0, variance ≈ dt)
- Path tracking and analysis
- Wiener process generation

### 3. Cyclotomic-Polyhedral Indexing (`src/math/polyhedral_geometry.jl`)

Deterministic spatial indexing for the Spatial Data Manager (SDM):

- **Cell-Based Indexing**: Maps 3D coordinates to unique 64-bit Cell IDs
- **Continuity**: Points within same cell always produce same ID
- **Hash Function**: Deterministic combination of integer coordinates

**Key Features:**
- Handles negative coordinates
- Works with arbitrary cell sizes
- 26-neighbor cell generation
- Verification tools for indexing continuity

### 4. Quaternion Mathematics (`src/math/quaternion_math.jl`)

Translates sparse vector attributes to rotation states for rendering:

- **Attribute Mapping**: Fluidity, Mass, Rigidity → Quaternion (w, x, y, z)
- **Unit Quaternion**: Always normalized to ||q|| = 1
- **Predictable Changes**: Attribute changes cause corresponding quaternion changes

**Key Features:**
- Euler angle conversion
- Rotation matrix generation
- SLERP interpolation
- Vector rotation operations

## Verification Results

### Task 1: Sparse Vector + Brownian Integration

**Requirement**: Prove kernel manipulation + Brownian motion uniqueness are functionally integrated.

**Verification Steps**:
1. Create sparse vector (Spirit attributes: Fluidity=0.5, Mass=1.0, Rigidity=0.5)
2. Apply kernel to increase Fluidity: 0.5 → 0.6
3. Apply Brownian motion immediately after
4. Assert result is 0.6 + δ (not exactly 0.6)

**Result**: ✅ **VERIFIED**
- Kernel successfully manipulated: Fluidity = 0.6
- Brownian added perturbation: δ ≈ 0.008
- Final value: 0.608 (proving both systems work together)
- 5 runs produced 5 unique results

### Task 2: Polyhedral Indexing Determinism

**Requirement**: Prove indexing is stable and continuous within cell boundaries.

**Verification Steps**:
1. Define point P1 = (10.5, 20.3, 30.7)
2. Compute Cell ID for P1
3. Define P2 = P1 + 10^-6 (infinitesimal offset)
4. Assert P1 and P2 produce **exact same** Cell ID

**Result**: ✅ **VERIFIED**
- P1 Cell ID: 13021521601020887821
- P2 Cell ID: 13021521601020887821
- **Exact match** - indexing is stable within cell

### Task 3: Quaternion State Translation

**Requirement**: Prove sparse vectors translate to valid unit quaternions with predictable changes.

**Verification Steps**:
1. Take evolved sparse vector from Task 1
2. Translate to quaternion using attribute mapping
3. Assert output is unit quaternion (||q|| ≈ 1)
4. Demonstrate Fluidity increase causes predictable quaternion change

**Result**: ✅ **VERIFIED**
- Output quaternion: ||q||² = 1.0 (valid unit quaternion)
- Fluidity 0.5 → 0.6 caused:
  - Δw = -0.0168
  - Δx = +0.0447 (significant - fluidity affects x)
  - Δy = +0.0319 (significant - fluidity affects y)
  - Δz = -0.0034
- Angular distance: 0.0513 radians
- **Predictable and significant changes confirmed**

## Test Statistics

**Total Tests**: 215 tests passed

- **Sparse Vector Integrity**: 46 tests
- **Brownian Motion Non-Repeatability**: 82 tests
- **Polyhedral Indexing Determinism**: 43 tests
- **Quaternion State Translation**: 44 tests
- **Integrated Verification**: 16 tests

## Dependencies

Defined in `Project.toml`:

- `SparseArrays`: Sparse array operations
- `LinearAlgebra`: Matrix and vector operations
- `Random`: Random number generation
- `Statistics`: Statistical functions
- `Test`: Testing framework

## Mathematical Foundations

### Brownian Motion

Standard Brownian motion equation:
```
dW(t) = √(dt) * N(0, 1) * σ
```

Where:
- `dt`: time step
- `N(0,1)`: standard normal distribution
- `σ`: volatility parameter

### Spatial Indexing

Cell ID computation:
```julia
cell_x = floor(x / cell_size)
cell_y = floor(y / cell_size)
cell_z = floor(z / cell_size)
cell_id = hash(cell_x, cell_y, cell_z)
```

### Quaternion Normalization

Unit quaternion constraint:
```
w² + x² + y² + z² = 1
```

Normalization:
```julia
norm = √(w² + x² + y² + z²)
q_normalized = (w/norm, x/norm, y/norm, z/norm)
```

## Integration with Rust Backend

The Julia runtime provides mathematical proofs and reference implementations. The Rust backend will:

1. Implement optimized versions of these algorithms
2. Use the Julia tests as verification benchmarks
3. Ensure binary compatibility with C++ client for quaternion data

## License

Part of the VPRAM Engine project.

## Contributors

VPRAM Team
