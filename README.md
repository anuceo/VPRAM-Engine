# VPRAM-Engine
Vector Parallel Random Access Memory

## Project Structure

- **`runtime/`** - Julia implementation of core mathematical operations
  - Sparse vector transformation kernels
  - Brownian motion for non-repeatability
  - Cyclotomic-polyhedral spatial indexing
  - Quaternion state translation
  - **`ffi/`** - FFI interface for Rust integration

- **`rust/`** - Rust integration layer
  - Zero-copy FFI with C-ABI compatible structures
  - HOGS (Hyperbolic Orthogonal Gang Scheduler) for safe concurrency
  - Memory safety and thread-safe kernel execution

## Mathematical Integrity Proven

The VPRAM engine's core mathematics has been formally verified through comprehensive testing:

### ✅ Task 1: Sparse Vector Integrity + Brownian Motion Non-Repeatability
- **46 tests**: Prove sparse vectors can be reliably manipulated by kernels
- **82 tests**: Prove Brownian motion ensures non-repeatability
- **Integration**: Kernel transformations + Brownian evolution work together seamlessly

### ✅ Task 2: Cyclotomic-Polyhedral Indexing Determinism  
- **43 tests**: Prove spatial indexing is stable and deterministic
- **Verified**: Points within cell boundaries always map to the same Cell ID
- **Critical for SDM**: Enables reliable Spatial Data Manager keying

### ✅ Task 3: Quaternion State Translation
- **44 tests**: Prove sparse vectors translate to valid unit quaternions
- **Verified**: Attribute changes produce predictable quaternion changes
- **Enables Rendering**: Quaternion Frame Manager can be driven by game's core data

**Total: 215 tests passed** across all modules including 16 integration tests.

See `runtime/README.md` for detailed documentation.

## Running Tests

### Julia Mathematical Core
```bash
cd runtime
julia test/runtests.jl
```

### Rust Integration Layer
```bash
cd rust
cargo test
```

## Architecture

The VPRAM Engine uses a **hybrid Julia-Rust architecture**:

```
┌─────────────────────────────────────────┐
│   Rust Application (Systems Layer)      │
│   • Concurrency control (HOGS)          │
│   • Memory safety                        │
│   • Thread synchronization               │
└──────────────┬──────────────────────────┘
               │ Zero-Copy FFI (C-ABI)
               ↓
┌─────────────────────────────────────────┐
│   Julia Mathematical Core                │
│   • Sparse vectors (Task 1)              │
│   • Brownian motion (Task 1)             │
│   • Spatial indexing (Task 2)            │
│   • Quaternions (Task 3)                 │
└─────────────────────────────────────────┘
```

**Key Features:**
- **Zero-copy data transfer** using `#[repr(C)]` structures
- **Cell-based locking** for safe concurrent kernel execution
- **Automatic Brownian evolution** ensures non-repeatability
- **Validated outputs**: Quaternions, Cell IDs checked before return

See `rust/README.md` for detailed FFI documentation.

## Status

✅ Core mathematical proofs complete (215 tests)  
✅ Rust FFI layer implemented  
✅ HOGS scheduler with spatial synchronization  
⏳ jlrs integration pending
