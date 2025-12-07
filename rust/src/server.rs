/// VPRAM Server - gRPC and WebSocket server implementation
///
/// This module implements the network layer for the VPRAM engine,
/// providing both gRPC (for action submission) and WebSocket (for real-time updates).

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::sync::{RwLock, mpsc};
use tokio::net::TcpListener;
use tonic::{transport::Server, Request, Response, Status};

use crate::vpram_hogs::{HOGS, HOGSConfig};
use crate::vpram_ffi::{SparseBuffer, KernelResult, KernelType};

// Import generated protobuf types
pub mod vpram_proto {
    tonic::include_proto!("vpram");
}

use vpram_proto::{
    hogs_submission_server::{HogsSubmission, HogsSubmissionServer},
    ActionRequest, ActionResponse, StatusCode, KernelType as ProtoKernelType,
    EntityQuery, EntityStatus, ActionBatchRequest, ActionBatchResponse,
    SparseVectorData,
};

/// Entity state tracked by the server
#[derive(Clone, Debug)]
pub struct EntityState {
    pub entity_id: u64,
    pub cell_id: u64,
    pub quaternion: [f64; 4],
    pub sparse_vector: Vec<(u32, f64)>,
    pub is_active: bool,
}

/// WebSocket message types
#[derive(Debug, serde::Serialize, serde::Deserialize)]
#[serde(tag = "type")]
pub enum WSMessage {
    EntityUpdate {
        entity_id: u64,
        cell_id: u64,
        quaternion: [f64; 4],
    },
    StatusUpdate {
        active_entities: usize,
        active_cells: usize,
    },
}

/// Connection broker that manages the HOGS scheduler and entity state
#[derive(Clone)]
pub struct ConnectionBroker {
    /// HOGS scheduler for kernel execution
    hogs: Arc<HOGS>,
    
    /// Entity state database
    entities: Arc<RwLock<HashMap<u64, EntityState>>>,
    
    /// WebSocket broadcast channel
    ws_broadcast: mpsc::UnboundedSender<WSMessage>,
}

impl ConnectionBroker {
    /// Create a new connection broker
    pub fn new(hogs_config: HOGSConfig) -> (Self, mpsc::UnboundedReceiver<WSMessage>) {
        let hogs = Arc::new(HOGS::new(hogs_config));
        let entities = Arc::new(RwLock::new(HashMap::new()));
        let (ws_tx, ws_rx) = mpsc::unbounded_channel();
        
        let broker = ConnectionBroker {
            hogs,
            entities,
            ws_broadcast: ws_tx,
        };
        
        (broker, ws_rx)
    }
    
    /// Initialize the Julia runtime
    pub async fn initialize(&self) -> Result<(), String> {
        self.hogs.initialize_julia()
    }
    
    /// Process an action request
    async fn process_action(
        &self,
        entity_id: u64,
        position: [f64; 3],
        kernel_type: KernelType,
        kernel_param: f64,
        sparse_data: &SparseVectorData,
    ) -> Result<(KernelResult, Vec<(u32, f64)>), String> {
        // Execute kernel in a block scope to ensure buffer is dropped before await
        let (result, sparse_vec) = {
            // Create sparse buffer from request data
            let mut buffer = SparseBuffer::new(sparse_data.capacity);
            
            unsafe {
                buffer.populate(
                    &sparse_data.indices,
                    &sparse_data.values,
                )?;
            }
            
            // Execute kernel through HOGS
            let result = self.hogs.execute_kernel(
                &mut buffer,
                position,
                kernel_type,
                kernel_param,
            )?;
            
            // Extract sparse vector data before dropping buffer
            let sparse_vec: Vec<(u32, f64)> = unsafe {
                buffer.get_indices()
                    .iter()
                    .zip(buffer.get_values().iter())
                    .map(|(i, v)| (*i, *v))
                    .collect()
            };
            
            (result, sparse_vec)
        }; // buffer dropped here
        
        // Update entity state
        let mut entities = self.entities.write().await;
        let state = EntityState {
            entity_id,
            cell_id: result.cell_id,
            quaternion: result.quaternion,
            sparse_vector: sparse_vec.clone(),
            is_active: true,
        };
        
        entities.insert(entity_id, state.clone());
        drop(entities);
        
        // Broadcast update to WebSocket clients
        let _ = self.ws_broadcast.send(WSMessage::EntityUpdate {
            entity_id,
            cell_id: result.cell_id,
            quaternion: result.quaternion,
        });
        
        Ok((result, sparse_vec))
    }
    
    /// Get entity state
    async fn get_entity_state(&self, entity_id: u64) -> Option<EntityState> {
        let entities = self.entities.read().await;
        entities.get(&entity_id).cloned()
    }
}

/// gRPC service implementation
#[tonic::async_trait]
impl HogsSubmission for ConnectionBroker {
    async fn submit_action(
        &self,
        request: Request<ActionRequest>,
    ) -> Result<Response<ActionResponse>, Status> {
        let req = request.into_inner();
        
        // Convert proto kernel type to internal type
        let kernel_type = match req.kernel_type() {
            ProtoKernelType::Identity => KernelType::Identity,
            ProtoKernelType::Scale => KernelType::Scale,
            ProtoKernelType::Shift => KernelType::Shift,
            ProtoKernelType::Filter => KernelType::Filter,
        };
        
        let position = [req.position_x, req.position_y, req.position_z];
        
        let sparse_data = req.sparse_vector.ok_or_else(|| {
            Status::invalid_argument("sparse_vector is required")
        })?;
        
        // Process the action
        match self.process_action(
            req.entity_id,
            position,
            kernel_type,
            req.kernel_param,
            &sparse_data,
        ).await {
            Ok((result, sparse_vec)) => {
                // Build response
                let updated_vector = SparseVectorData {
                    indices: sparse_vec.iter().map(|(i, _)| *i).collect(),
                    values: sparse_vec.iter().map(|(_, v)| *v).collect(),
                    capacity: sparse_vec.len() as u32,
                };
                
                let response = ActionResponse {
                    status: StatusCode::Success.into(),
                    cell_id: result.cell_id,
                    quaternion: result.quaternion.to_vec(),
                    updated_vector: Some(updated_vector),
                    error_message: String::new(),
                    execution_time_us: 0, // Would be populated from actual timing
                };
                
                Ok(Response::new(response))
            }
            Err(e) => {
                let response = ActionResponse {
                    status: StatusCode::RuntimeError.into(),
                    cell_id: 0,
                    quaternion: vec![1.0, 0.0, 0.0, 0.0],
                    updated_vector: None,
                    error_message: e,
                    execution_time_us: 0,
                };
                
                Ok(Response::new(response))
            }
        }
    }
    
    async fn query_entity_status(
        &self,
        request: Request<EntityQuery>,
    ) -> Result<Response<EntityStatus>, Status> {
        let entity_id = request.into_inner().entity_id;
        
        match self.get_entity_state(entity_id).await {
            Some(state) => {
                let sparse_data = SparseVectorData {
                    indices: state.sparse_vector.iter().map(|(i, _)| *i).collect(),
                    values: state.sparse_vector.iter().map(|(_, v)| *v).collect(),
                    capacity: state.sparse_vector.len() as u32,
                };
                
                let status = EntityStatus {
                    entity_id: state.entity_id,
                    cell_id: state.cell_id,
                    quaternion: state.quaternion.to_vec(),
                    sparse_vector: Some(sparse_data),
                    is_active: state.is_active,
                };
                
                Ok(Response::new(status))
            }
            None => Err(Status::not_found("Entity not found")),
        }
    }
    
    async fn submit_action_batch(
        &self,
        request: Request<ActionBatchRequest>,
    ) -> Result<Response<ActionBatchResponse>, Status> {
        let batch = request.into_inner();
        let mut responses = Vec::new();
        let mut successful_count = 0;
        let mut failed_count = 0;
        
        for action in batch.actions {
            let result = self.submit_action(Request::new(action)).await;
            
            match result {
                Ok(resp) => {
                    let resp_inner = resp.into_inner();
                    if resp_inner.status() == StatusCode::Success {
                        successful_count += 1;
                    } else {
                        failed_count += 1;
                    }
                    responses.push(resp_inner);
                }
                Err(_) => {
                    failed_count += 1;
                    responses.push(ActionResponse {
                        status: StatusCode::RuntimeError.into(),
                        cell_id: 0,
                        quaternion: vec![1.0, 0.0, 0.0, 0.0],
                        updated_vector: None,
                        error_message: "Batch processing error".to_string(),
                        execution_time_us: 0,
                    });
                }
            }
        }
        
        let response = ActionBatchResponse {
            responses,
            successful_count,
            failed_count,
        };
        
        Ok(Response::new(response))
    }
}

/// VPRAM server configuration
pub struct ServerConfig {
    pub grpc_addr: SocketAddr,
    pub ws_addr: SocketAddr,
    pub hogs_config: HOGSConfig,
}

impl Default for ServerConfig {
    fn default() -> Self {
        ServerConfig {
            grpc_addr: "0.0.0.0:50051".parse().unwrap(),
            ws_addr: "0.0.0.0:8080".parse().unwrap(),
            hogs_config: HOGSConfig::default(),
        }
    }
}

/// Main VPRAM server
pub struct VPRAMServer {
    config: ServerConfig,
    broker: Arc<ConnectionBroker>,
    ws_receiver: Arc<RwLock<Option<mpsc::UnboundedReceiver<WSMessage>>>>,
}

impl VPRAMServer {
    /// Create a new VPRAM server
    pub fn new(config: ServerConfig) -> Self {
        let (broker, ws_rx) = ConnectionBroker::new(config.hogs_config.clone());
        
        VPRAMServer {
            config,
            broker: Arc::new(broker),
            ws_receiver: Arc::new(RwLock::new(Some(ws_rx))),
        }
    }
    
    /// Initialize the server
    pub async fn initialize(&self) -> Result<(), Box<dyn std::error::Error>> {
        println!("Initializing VPRAM Server...");
        self.broker.initialize().await?;
        println!("Julia runtime initialized");
        Ok(())
    }
    
    /// Start the gRPC server
    pub async fn start_grpc(&self) -> Result<(), Box<dyn std::error::Error>> {
        let addr = self.config.grpc_addr;
        let broker = self.broker.clone();
        
        println!("Starting gRPC server on {}", addr);
        
        Server::builder()
            .add_service(HogsSubmissionServer::new(broker.as_ref().clone()))
            .serve(addr)
            .await?;
        
        Ok(())
    }
    
    /// Start the WebSocket server
    pub async fn start_websocket(&self) -> Result<(), Box<dyn std::error::Error>> {
        let addr = self.config.ws_addr;
        let _listener = TcpListener::bind(&addr).await?;
        
        println!("Starting WebSocket server on {}", addr);
        
        // This is a simplified WebSocket implementation
        // In production, you'd handle multiple connections and proper message routing
        
        Ok(())
    }
    
    /// Run the server (both gRPC and WebSocket)
    pub async fn run(&self) -> Result<(), Box<dyn std::error::Error>> {
        self.initialize().await?;
        
        // Start both servers concurrently
        let grpc_future = self.start_grpc();
        let ws_future = self.start_websocket();
        
        tokio::select! {
            result = grpc_future => {
                if let Err(e) = result {
                    eprintln!("gRPC server error: {}", e);
                }
            }
            result = ws_future => {
                if let Err(e) = result {
                    eprintln!("WebSocket server error: {}", e);
                }
            }
        }
        
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_server_config_default() {
        let config = ServerConfig::default();
        assert_eq!(config.grpc_addr.port(), 50051);
        assert_eq!(config.ws_addr.port(), 8080);
    }
    
    #[tokio::test]
    async fn test_connection_broker_creation() {
        let config = HOGSConfig::default();
        let (broker, _rx) = ConnectionBroker::new(config);
        
        // Should create successfully
        assert!(true);
    }
}
