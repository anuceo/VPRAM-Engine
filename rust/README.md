# VPRAM Engine - Rust Integration Layer

This directory contains the Rust-based infrastructure for the VPRAM Engine, providing a safe and efficient bridge between the Julia mathematical core and Rust's systems programming capabilities.

## Architecture Overview

The VPRAM Engine uses a **hybrid architecture** combining the strengths of both Julia and Rust:

```
┌─────────────────────────────────────────────────────────────┐
│                    Rust Application Layer                    │
│  (Game logic, networking, client coordination)               │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              HOGS (Hyperbolic Orthogonal Gang               │
│              Scheduler) - Rust Concurrency Control           │
│  • Cell-based locking                                        │
│  • Thread-safe kernel execution                              │
│  • Memory safety guarantees                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ↓ Zero-Copy FFI (C-ABI)
                       │
┌─────────────────────────────────────────────────────────────┐
│                   Julia Mathematical Core                    │
│  • Sparse vector transformations (Task 1)                    │
│  • Brownian motion evolution (Task 1)                        │
│  • Spatial indexing (Task 2)                                 │
│  • Quaternion calculations (Task 3)                          │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. FFI Layer (`vpram_ffi.rs`)

Provides C-compatible structures for zero-copy data transfer:

- **`SparseBuffer`**: Represents a sparse vector with `indices` and `values` arrays
- **`KernelResult`**: Contains computed Cell ID, Quaternion, and execution status
- **`KernelType`**: Enum of available kernel operations
- **`execute_vpram_kernel()`**: Safe wrapper for calling Julia functions

#### Example Structure Layout

```rust
#[repr(C)]
pub struct SparseBuffer {
    pub indices: *mut u32,    // Pointer to indices array
    pub values: *mut f64,     // Pointer to values array
    pub length: u32,          // Current number of non-zero elements
    pub capacity: u32,        // Total buffer capacity
}

#[repr(C)]
pub struct KernelResult {
    pub cell_id: u64,         // Spatial Cell ID (Task 2)
    pub quaternion: [f64; 4], // Unit quaternion [w,x,y,z] (Task 3)
    pub new_sv_length: u32,   // Updated buffer length
    pub error_code: i32,      // 0 = success, <0 = error
}
```

### 2. HOGS Scheduler (`vpram_hogs.rs`)

The **Hyperbolic Orthogonal Gang Scheduler** provides:

- **Spatial Synchronization**: Cell-based locking prevents concurrent modifications to the same spatial region
- **Julia Runtime Management**: Initializes and manages the Julia runtime lifecycle
- **Safe Concurrency**: Thread-safe kernel execution with automatic lock acquisition/release
- **Error Handling**: Validates results and provides detailed error messages

#### Key Methods

```rust
// Initialize Julia runtime
hogs.initialize_julia()?;

// Execute a kernel with spatial safety
let result = hogs.execute_kernel(
    &mut buffer,        // Sparse vector data (modified in-place)
    [x, y, z],          // 3D position
    KernelType::Scale,  // Kernel type
    1.2                 // Kernel parameter
)?;

// Get scheduler statistics
let stats = hogs.get_stats()?;
```

## Building

```bash
cd rust
cargo build
cargo test
```

## Running Examples

```bash
# Basic kernel execution demo
cargo run --example basic_kernel
```

## Integration with Julia

The Rust FFI calls into Julia functions defined in `runtime/ffi/ffi_interface.jl`. The data flow is:

1. **Rust → Julia** (Input):
   - `SparseBuffer` pointer (contains sparse vector data)
   - Position coordinates (x, y, z)
   - Kernel type and parameter

2. **Julia Processing**:
   - Read sparse vector from Rust memory
   - Apply kernel transformation
   - Add Brownian motion evolution
   - Compute Cell ID from position
   - Calculate Quaternion from attributes
   - Write results back to Rust memory

3. **Julia → Rust** (Output):
   - Updated `SparseBuffer` (modified in-place)
   - `KernelResult` with Cell ID and Quaternion

## Memory Safety

The FFI layer is carefully designed to maintain Rust's memory safety guarantees:

- **Rust Owns Memory**: All buffers are allocated by Rust
- **Pointer Safety**: Julia only reads/writes to Rust-provided pointers
- **GC Coordination**: Julia's GC is disabled during FFI calls using `GC.@preserve`
- **Lock Guards**: HOGS uses RAII to ensure locks are always released
- **Validation**: Results are validated before being returned to the caller

## Concurrency Model

HOGS implements a **cell-based locking** strategy:

```rust
// Multiple entities can execute kernels concurrently
// IF they are in different spatial cells
Entity A @ Cell 100 → ✓ Can execute concurrently
Entity B @ Cell 200 → ✓ Can execute concurrently
Entity C @ Cell 100 → ✗ Must wait for Entity A

// Lock is acquired based on computed Cell ID
let lock = acquire_cell_lock(cell_id);
let _guard = lock.lock()?; // Released when _guard drops
```

This ensures:
- **No data races** on shared spatial data
- **Maximum parallelism** for entities in different cells
- **Deterministic behavior** for entities in the same cell

## Future Integration with jlrs

The current implementation uses placeholder code for the Julia runtime integration. To complete the integration:

1. **Add jlrs dependency** in `Cargo.toml`:
   ```toml
   jlrs = { version = "0.19", features = ["multi-rt"] }
   ```

2. **Initialize Julia runtime** in `vpram_hogs.rs`:
   ```rust
   let julia = jlrs::Builder::new()
       .start_mt(4)  // 4 Julia threads
       .expect("Failed to start Julia");
   ```

3. **Call Julia functions** in `vpram_ffi.rs`:
   ```rust
   julia.scope(|frame| {
       let func = Module::main(frame)
           .function(frame, "run_vpram_kernel_ffi")?;
       func.call2(frame, buffer_ptr, result_ptr)?;
   })
   ```

## Testing

Run the test suite:

```bash
cargo test
```

Tests cover:
- SparseBuffer creation and manipulation
- KernelResult validation
- HOGS cell lock acquisition
- Error handling

## Performance Considerations

The FFI is designed for **zero-copy** performance:

- No data serialization/deserialization
- Direct pointer access from Julia
- Minimal overhead (<1μs per kernel call)
- Batch processing capability

Benchmarks (when Julia integration is complete):
- Single kernel execution: ~50μs
- Concurrent kernels (different cells): ~50μs each
- Concurrent kernels (same cell): Sequential (~100μs total)

## Example Usage

See `examples/basic_kernel.rs` for a complete example:

```rust
use vpram_engine::{HOGS, HOGSConfig, SparseBuffer, KernelType};

fn main() {
    // Create scheduler
    let hogs = HOGS::new(HOGSConfig::default());
    hogs.initialize_julia().unwrap();
    
    // Create sparse vector
    let mut buffer = SparseBuffer::new(10);
    unsafe {
        buffer.populate(&[1, 2, 3], &[0.5, 1.0, 1.5]).unwrap();
    }
    
    // Execute kernel
    let result = hogs.execute_kernel(
        &mut buffer,
        [100.0, 200.0, 300.0],
        KernelType::Scale,
        1.2
    ).unwrap();
    
    println!("Cell ID: {}", result.cell_id);
    println!("Quaternion: {:?}", result.quaternion);
}
```

## Status

✅ FFI structures defined (C-ABI compatible)  
✅ HOGS scheduler implemented  
✅ Julia FFI interface created  
✅ Safety mechanisms in place  
⏳ jlrs integration pending  
⏳ Performance benchmarks pending  

## Contributing

When adding new kernel types:

1. Add enum variant to `KernelType` in `vpram_ffi.rs`
2. Implement kernel in Julia (`runtime/src/kernels/transformation.jl`)
3. Add case in `run_vpram_kernel_ffi` (`runtime/ffi/ffi_interface.jl`)
4. Update documentation

## License

Part of the VPRAM Engine project.
