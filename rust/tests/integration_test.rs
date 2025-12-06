/// Integration tests for VPRAM FFI
///
/// These tests verify the Rust-side functionality is working correctly.
/// Full Julia integration tests will be added once jlrs is integrated.

use vpram_engine::{SparseBuffer, KernelResult, KernelType, HOGS, HOGSConfig};

#[test]
fn test_sparse_buffer_lifecycle() {
    let mut buffer = SparseBuffer::new(10);
    assert_eq!(buffer.length, 0);
    assert_eq!(buffer.capacity, 10);
    
    let indices = vec![1, 2, 3, 4];
    let values = vec![0.5, 1.0, 0.5, 1.0];
    
    unsafe {
        buffer.populate(&indices, &values).expect("Failed to populate buffer");
        assert_eq!(buffer.length, 4);
        let buf_indices = buffer.get_indices();
        let buf_values = buffer.get_values();
        assert_eq!(buf_indices, &[1, 2, 3, 4]);
        assert_eq!(buf_values, &[0.5, 1.0, 0.5, 1.0]);
    }
}

#[test]
fn test_kernel_result_quaternion_validation() {
    let result_valid = KernelResult {
        cell_id: 12345,
        quaternion: [1.0, 0.0, 0.0, 0.0],
        new_sv_length: 4,
        error_code: 0,
    };
    assert!(result_valid.verify_quaternion());
    
    let result_invalid = KernelResult {
        cell_id: 12345,
        quaternion: [2.0, 0.0, 0.0, 0.0],
        new_sv_length: 4,
        error_code: 0,
    };
    assert!(!result_invalid.verify_quaternion());
}

#[test]
fn test_hogs_initialization() {
    let config = HOGSConfig {
        cell_size: 1.0,
        max_concurrent_kernels: 4,
        verbose: false,
    };
    
    let hogs = HOGS::new(config);
    let stats = hogs.get_stats().expect("Failed to get stats");
    assert_eq!(stats.active_cell_count, 0);
    assert_eq!(stats.max_concurrent_kernels, 4);
}

#[test]
fn test_kernel_type_conversion() {
    assert_eq!(u32::from(KernelType::Identity), 0);
    assert_eq!(u32::from(KernelType::Scale), 1);
    assert_eq!(u32::from(KernelType::Shift), 2);
    assert_eq!(u32::from(KernelType::Filter), 3);
}
