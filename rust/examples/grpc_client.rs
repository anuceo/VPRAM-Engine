/// gRPC Client Example
///
/// Demonstrates how to connect to the VPRAM server and submit actions.

use vpram_engine::server::vpram_proto::{
    hogs_submission_client::HogsSubmissionClient,
    ActionRequest, SparseVectorData, KernelType,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("VPRAM gRPC Client Example");
    println!("==========================\n");
    
    // Connect to the server
    let mut client = HogsSubmissionClient::connect("http://127.0.0.1:50051").await?;
    println!("Connected to VPRAM server\n");
    
    // Create a sparse vector for a Spirit entity
    let sparse_vector = SparseVectorData {
        indices: vec![1, 2, 3, 4],
        values: vec![0.5, 1.0, 0.5, 1.0],
        capacity: 10,
    };
    
    // Create an action request
    let request = ActionRequest {
        entity_id: 12345,
        position_x: 100.5,
        position_y: 200.7,
        position_z: 300.3,
        kernel_type: KernelType::Scale.into(),
        kernel_param: 1.2,
        sparse_vector: Some(sparse_vector),
    };
    
    println!("Submitting action for entity {}...", request.entity_id);
    println!("  Position: ({}, {}, {})", request.position_x, request.position_y, request.position_z);
    println!("  Kernel: Scale by {}", request.kernel_param);
    println!();
    
    // Submit the action
    let response = client.submit_action(request).await?;
    let result = response.into_inner();
    
    println!("Action Result:");
    println!("  Status: {:?}", result.status());
    println!("  Cell ID: {}", result.cell_id);
    println!("  Quaternion: [{:.4}, {:.4}, {:.4}, {:.4}]",
        result.quaternion[0],
        result.quaternion[1],
        result.quaternion[2],
        result.quaternion[3]
    );
    
    if let Some(updated_vec) = result.updated_vector {
        println!("  Updated Vector:");
        for (idx, val) in updated_vec.indices.iter().zip(updated_vec.values.iter()) {
            println!("    Index {}: {:.4}", idx, val);
        }
    }
    
    if !result.error_message.is_empty() {
        println!("  Error: {}", result.error_message);
    }
    
    println!("\nExample complete!");
    
    Ok(())
}
