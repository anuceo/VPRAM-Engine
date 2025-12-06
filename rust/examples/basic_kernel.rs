/// Basic Kernel Execution Example
///
/// This example demonstrates how to use the VPRAM Engine Rust FFI
/// to execute mathematical kernels on sparse vectors.

use vpram_engine::{HOGS, HOGSConfig, SparseBuffer, KernelType};

fn main() {
    println!("VPRAM Engine - Basic Kernel Execution Example");
    println!("==============================================\n");
    
    // Step 1: Create and configure the HOGS scheduler
    let config = HOGSConfig {
        cell_size: 1.0,
        max_concurrent_kernels: 4,
        verbose: true,
    };
    
    let hogs = HOGS::new(config);
    
    // Step 2: Initialize Julia runtime
    println!("Initializing Julia runtime...");
    match hogs.initialize_julia() {
        Ok(_) => println!("Julia runtime initialized successfully\n"),
        Err(e) => {
            eprintln!("Failed to initialize Julia: {}", e);
            eprintln!("Note: This is expected until jlrs integration is complete");
            println!("\nContinuing with demonstration of Rust API...\n");
        }
    }
    
    // Step 3: Create a sparse vector buffer representing a Spirit's attributes
    println!("Creating sparse vector buffer (Spirit attributes)...");
    let mut buffer = SparseBuffer::new(10);
    
    // Populate with initial attributes:
    // Index 1: Fluidity = 0.5
    // Index 2: Mass = 1.0
    // Index 3: Rigidity = 0.5
    // Index 4: Energy = 1.0
    let indices = vec![1, 2, 3, 4];
    let values = vec![0.5, 1.0, 0.5, 1.0];
    
    unsafe {
        buffer.populate(&indices, &values).expect("Failed to populate buffer");
        
        println!("Initial sparse vector:");
        for (idx, val) in buffer.get_indices().iter().zip(buffer.get_values().iter()) {
            println!("  Index {}: {}", idx, val);
        }
    }
    println!();
    
    // Step 4: Define entity position in 3D space
    let position = [100.5, 200.7, 300.3];
    println!("Entity position: [{}, {}, {}]\n", position[0], position[1], position[2]);
    
    // Step 5: Execute a scale kernel (increase all attributes by 20%)
    println!("Executing Scale Kernel (factor = 1.2)...");
    match hogs.execute_kernel(&mut buffer, position, KernelType::Scale, 1.2) {
        Ok(result) => {
            println!("Kernel execution successful!");
            println!("  Cell ID: {}", result.cell_id);
            println!("  Quaternion: w={:.4}, x={:.4}, y={:.4}, z={:.4}",
                    result.quaternion[0], result.quaternion[1],
                    result.quaternion[2], result.quaternion[3]);
            println!("  Updated vector length: {}", result.new_sv_length);
            println!("  Quaternion valid: {}", result.verify_quaternion());
            
            unsafe {
                println!("\nUpdated sparse vector (after kernel + Brownian motion):");
                for (idx, val) in buffer.get_indices().iter().zip(buffer.get_values().iter()) {
                    println!("  Index {}: {:.6}", idx, val);
                }
            }
        }
        Err(e) => {
            eprintln!("Kernel execution failed: {}", e);
            eprintln!("Note: This is expected until jlrs integration is complete");
        }
    }
    println!();
    
    // Step 6: Show scheduler statistics
    match hogs.get_stats() {
        Ok(stats) => {
            println!("HOGS Statistics:");
            println!("  Active cells: {}", stats.active_cell_count);
            println!("  Max concurrent kernels: {}", stats.max_concurrent_kernels);
        }
        Err(e) => eprintln!("Failed to get stats: {}", e),
    }
    println!();
    
    // Step 7: Demonstrate different kernel types
    println!("Available Kernel Types:");
    println!("  - Identity: No transformation (preserves structure)");
    println!("  - Scale: Multiply values by factor");
    println!("  - Shift: Add offset to values");
    println!("  - Filter: Remove values below threshold");
    println!();
    
    // Cleanup is automatic when hogs goes out of scope
    println!("Example complete. HOGS will shutdown automatically.");
}
