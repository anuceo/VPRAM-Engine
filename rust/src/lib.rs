/// VPRAM Engine - Rust Integration Layer
///
/// This crate provides the Rust-based infrastructure for the VPRAM Engine,
/// bridging the high-performance Julia mathematical core with Rust's systems
/// programming capabilities.
///
/// # Architecture
///
/// The VPRAM Engine uses a hybrid architecture:
/// - **Julia**: Mathematical operations (sparse vectors, Brownian motion, spatial indexing, quaternions)
/// - **Rust**: System coordination, concurrency control, memory safety
/// - **FFI**: Zero-copy data transfer using C-ABI compatible structures
///
/// # Main Components
///
/// - `vpram_ffi`: FFI structures and wrappers for Julia integration
/// - `vpram_hogs`: Hyperbolic Orthogonal Gang Scheduler for concurrent kernel execution
///
/// # Example Usage
///
/// ```rust,ignore
/// use vpram_engine::{HOGS, HOGSConfig, SparseBuffer, KernelType};
///
/// // Initialize the scheduler
/// let hogs = HOGS::new(HOGSConfig::default());
/// hogs.initialize_julia().expect("Failed to initialize Julia");
///
/// // Create a sparse vector buffer
/// let mut buffer = SparseBuffer::new(10);
/// unsafe {
///     buffer.populate(&[1, 2, 3], &[0.5, 1.0, 1.5]).unwrap();
/// }
///
/// // Execute a kernel
/// let position = [100.5, 200.7, 300.3];
/// let result = hogs.execute_kernel(
///     &mut buffer,
///     position,
///     KernelType::Scale,
///     1.2
/// ).expect("Kernel execution failed");
///
/// println!("Cell ID: {}", result.cell_id);
/// println!("Quaternion: {:?}", result.quaternion);
/// ```

pub mod vpram_ffi;
pub mod vpram_hogs;
pub mod server;

// Re-export main types for convenience
pub use vpram_ffi::{SparseBuffer, KernelResult, KernelType, execute_vpram_kernel};
pub use vpram_hogs::{HOGS, HOGSConfig, HOGSStats};
pub use server::{VPRAMServer, ServerConfig, ConnectionBroker};

/// Version information
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
pub const JULIA_FFI_VERSION: &str = "0.1.0";

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_version_info() {
        assert!(!VERSION.is_empty());
        assert!(!JULIA_FFI_VERSION.is_empty());
    }
}
