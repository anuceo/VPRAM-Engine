/// VPRAM Server Binary
///
/// This is the main server executable that runs the VPRAM Engine
/// with both gRPC and WebSocket endpoints.

use vpram_engine::{VPRAMServer, ServerConfig, HOGSConfig};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("========================================");
    println!("  VPRAM Engine Server");
    println!("  Version: {}", vpram_engine::VERSION);
    println!("========================================\n");
    
    // Configure the server
    let server_config = ServerConfig {
        grpc_addr: "0.0.0.0:50051".parse()?,
        ws_addr: "0.0.0.0:8080".parse()?,
        hogs_config: HOGSConfig {
            cell_size: 1.0,
            max_concurrent_kernels: 32,
            verbose: true,
        },
    };
    
    println!("Server Configuration:");
    println!("  gRPC Address: {}", server_config.grpc_addr);
    println!("  WebSocket Address: {}", server_config.ws_addr);
    println!("  HOGS Cell Size: {}", server_config.hogs_config.cell_size);
    println!("  Max Concurrent Kernels: {}", server_config.hogs_config.max_concurrent_kernels);
    println!();
    
    // Create and run the server
    let server = VPRAMServer::new(server_config);
    
    println!("Starting VPRAM Server...");
    server.run().await?;
    
    Ok(())
}
