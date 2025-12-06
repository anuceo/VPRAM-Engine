/// VPRAM FFI Module
///
/// This module provides the Foreign Function Interface (FFI) between Rust and Julia.
/// It defines C-compatible data structures and provides safe wrappers for calling
/// Julia mathematical functions from Rust.

// Reserved for future use when integrating with C FFI
// use std::os::raw::{c_int, c_double};

/// C-compatible sparse vector buffer
///
/// This structure allows zero-copy data transfer between Rust and Julia.
/// Rust allocates the memory, and Julia reads/writes to it using raw pointers.
#[repr(C)]
#[derive(Debug)]
pub struct SparseBuffer {
    /// Pointer to array of indices (attribute IDs)
    pub indices: *mut u32,
    /// Pointer to array of non-zero values (coefficients)
    pub values: *mut f64,
    /// Number of non-zero entries currently stored
    pub length: u32,
    /// Total capacity of the allocated arrays
    pub capacity: u32,
}

impl SparseBuffer {
    /// Create a new SparseBuffer with the given capacity
    ///
    /// # Safety
    /// The caller must ensure that the buffer is properly deallocated
    /// using `drop_buffer` when no longer needed.
    pub fn new(capacity: u32) -> Self {
        let indices = vec![0u32; capacity as usize].into_boxed_slice();
        let values = vec![0.0f64; capacity as usize].into_boxed_slice();
        
        let indices_ptr = Box::into_raw(indices) as *mut u32;
        let values_ptr = Box::into_raw(values) as *mut f64;
        
        SparseBuffer {
            indices: indices_ptr,
            values: values_ptr,
            length: 0,
            capacity,
        }
    }
    
    /// Populate the buffer with initial data
    ///
    /// # Safety
    /// The caller must ensure indices and values have the same length
    /// and that length does not exceed capacity.
    pub unsafe fn populate(&mut self, indices: &[u32], values: &[f64]) -> Result<(), &'static str> {
        if indices.len() != values.len() {
            return Err("Indices and values must have same length");
        }
        
        if indices.len() > self.capacity as usize {
            return Err("Data exceeds buffer capacity");
        }
        
        // Copy data into the buffer
        std::ptr::copy_nonoverlapping(indices.as_ptr(), self.indices, indices.len());
        std::ptr::copy_nonoverlapping(values.as_ptr(), self.values, values.len());
        
        self.length = indices.len() as u32;
        
        Ok(())
    }
    
    /// Get the current indices as a slice
    ///
    /// # Safety
    /// The caller must ensure the buffer is still valid and not accessed concurrently.
    pub unsafe fn get_indices(&self) -> &[u32] {
        std::slice::from_raw_parts(self.indices, self.length as usize)
    }
    
    /// Get the current values as a slice
    ///
    /// # Safety
    /// The caller must ensure the buffer is still valid and not accessed concurrently.
    pub unsafe fn get_values(&self) -> &[f64] {
        std::slice::from_raw_parts(self.values, self.length as usize)
    }
}

impl Drop for SparseBuffer {
    fn drop(&mut self) {
        unsafe {
            if !self.indices.is_null() {
                let _ = Box::from_raw(std::slice::from_raw_parts_mut(
                    self.indices,
                    self.capacity as usize,
                ));
            }
            if !self.values.is_null() {
                let _ = Box::from_raw(std::slice::from_raw_parts_mut(
                    self.values,
                    self.capacity as usize,
                ));
            }
        }
    }
}

/// Output structure containing kernel execution results
///
/// This structure is filled by Julia with the results of kernel execution,
/// including the computed Cell ID, Quaternion, and updated sparse vector length.
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct KernelResult {
    /// Cell ID of the entity's current location (from Task 2)
    pub cell_id: u64,
    /// The 4 components of the unit quaternion [w, x, y, z] (from Task 3)
    pub quaternion: [f64; 4],
    /// Length of the updated sparse buffer (must be <= capacity)
    pub new_sv_length: u32,
    /// Error code (0 on success, negative on error)
    pub error_code: i32,
}

impl KernelResult {
    /// Check if the kernel execution was successful
    pub fn is_success(&self) -> bool {
        self.error_code == 0
    }
    
    /// Get error message for the error code
    pub fn error_message(&self) -> &'static str {
        match self.error_code {
            0 => "Success",
            -1 => "Buffer overflow",
            -2 => "Unknown kernel type",
            -99 => "Julia runtime error",
            _ => "Unknown error",
        }
    }
    
    /// Verify the quaternion is a valid unit quaternion
    pub fn verify_quaternion(&self) -> bool {
        let norm_squared = self.quaternion[0].powi(2) +
                          self.quaternion[1].powi(2) +
                          self.quaternion[2].powi(2) +
                          self.quaternion[3].powi(2);
        (norm_squared - 1.0).abs() < 1e-6
    }
}

/// Kernel types supported by the FFI
#[repr(u32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KernelType {
    /// Identity kernel - no transformation
    Identity = 0,
    /// Scale kernel - multiply values by parameter
    Scale = 1,
    /// Shift kernel - add parameter to values
    Shift = 2,
    /// Filter kernel - remove values below parameter threshold
    Filter = 3,
}

impl From<KernelType> for u32 {
    fn from(kt: KernelType) -> u32 {
        kt as u32
    }
}

/// Safe wrapper for calling the Julia FFI function
///
/// This function provides a safe Rust interface to the Julia kernel execution.
/// It handles the unsafe FFI call and validates results.
///
/// # Parameters
/// - `buffer`: Mutable reference to the sparse vector buffer (input/output)
/// - `position`: Entity's 3D position [x, y, z]
/// - `kernel_type`: Type of kernel to apply
/// - `kernel_param`: Parameter for the kernel operation
///
/// # Returns
/// `Ok(KernelResult)` on success, `Err` on failure
pub fn execute_vpram_kernel(
    _buffer: &mut SparseBuffer,
    _position: [f64; 3],
    _kernel_type: KernelType,
    _kernel_param: f64,
) -> Result<KernelResult, String> {
    // This will be implemented when we integrate with jlrs
    // For now, this is a placeholder showing the interface
    
    let _result = KernelResult {
        cell_id: 0,
        quaternion: [1.0, 0.0, 0.0, 0.0],
        new_sv_length: 0,
        error_code: -999, // Not implemented
    };
    
    // The actual implementation will use jlrs to call Julia:
    // unsafe {
    //     run_vpram_kernel_ffi(
    //         buffer as *mut SparseBuffer,
    //         &mut result as *mut KernelResult,
    //         position[0], position[1], position[2],
    //         kernel_type.into(),
    //         kernel_param
    //     )
    // }
    
    Err("Julia FFI not yet integrated - requires jlrs setup".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_sparse_buffer_creation() {
        let buffer = SparseBuffer::new(10);
        assert_eq!(buffer.capacity, 10);
        assert_eq!(buffer.length, 0);
        assert!(!buffer.indices.is_null());
        assert!(!buffer.values.is_null());
    }
    
    #[test]
    fn test_sparse_buffer_populate() {
        let mut buffer = SparseBuffer::new(10);
        let indices = vec![1, 2, 3];
        let values = vec![0.5, 1.0, 1.5];
        
        unsafe {
            buffer.populate(&indices, &values).unwrap();
            assert_eq!(buffer.length, 3);
            
            let buf_indices = buffer.get_indices();
            let buf_values = buffer.get_values();
            
            assert_eq!(buf_indices, &[1, 2, 3]);
            assert_eq!(buf_values, &[0.5, 1.0, 1.5]);
        }
    }
    
    #[test]
    fn test_kernel_result_validation() {
        let result = KernelResult {
            cell_id: 12345,
            quaternion: [1.0, 0.0, 0.0, 0.0],
            new_sv_length: 5,
            error_code: 0,
        };
        
        assert!(result.is_success());
        assert!(result.verify_quaternion());
        assert_eq!(result.error_message(), "Success");
    }
    
    #[test]
    fn test_kernel_result_error() {
        let result = KernelResult {
            cell_id: 0,
            quaternion: [0.0, 0.0, 0.0, 0.0],
            new_sv_length: 0,
            error_code: -1,
        };
        
        assert!(!result.is_success());
        assert_eq!(result.error_message(), "Buffer overflow");
    }
}
