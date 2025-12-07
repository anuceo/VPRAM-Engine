#include "vpram_async_client.h"
#include <iostream>
#include <chrono>

namespace vpram {

VPRAMAsyncClient::VPRAMAsyncClient(const std::string& server_address) {
    // Create a gRPC channel to the server
    channel_ = grpc::CreateChannel(server_address, grpc::InsecureChannelCredentials());
    stub_ = vpram::HOGSSubmission::NewStub(channel_);
}

VPRAMAsyncClient::~VPRAMAsyncClient() {
    if (running_.load()) {
        Shutdown();
    }
}

void VPRAMAsyncClient::Start() {
    if (running_.load()) {
        std::cerr << "VPRAMAsyncClient: Already running" << std::endl;
        return;
    }
    
    running_.store(true);
    worker_thread_ = std::thread(&VPRAMAsyncClient::AsyncWorkerThread, this);
}

void VPRAMAsyncClient::Shutdown() {
    if (!running_.load()) {
        return;
    }
    
    // Signal shutdown
    running_.store(false);
    
    // Shutdown the completion queue to wake up the worker thread
    cq_.Shutdown();
    
    // Wait for the worker thread to finish
    if (worker_thread_.joinable()) {
        worker_thread_.join();
    }
    
    // Drain any remaining events
    void* tag;
    bool ok;
    while (cq_.Next(&tag, &ok)) {
        auto* call_data = static_cast<ClientCallData*>(tag);
        if (call_data->callback) {
            // Notify callback of cancellation
            grpc::Status cancelled_status(grpc::StatusCode::CANCELLED, "Client shutdown");
            call_data->callback(call_data->reply, cancelled_status);
        }
        delete call_data;
    }
}

void VPRAMAsyncClient::SubmitAction(const vpram::ActionRequest& request, 
                                    ActionCallback callback) {
    if (!running_.load()) {
        std::cerr << "VPRAMAsyncClient: Cannot submit action - client not running" << std::endl;
        if (callback) {
            vpram::ActionResponse empty_response;
            grpc::Status error(grpc::StatusCode::FAILED_PRECONDITION, "Client not running");
            callback(empty_response, error);
        }
        return;
    }
    
    // Create call-specific data
    auto* call_data = new ClientCallData(std::move(callback));
    
    // Set a deadline for the request (e.g., 5 seconds from now)
    std::chrono::system_clock::time_point deadline = 
        std::chrono::system_clock::now() + std::chrono::seconds(5);
    call_data->context.set_deadline(deadline);
    
    // Initiate the async RPC call
    call_data->rpc = stub_->AsyncSubmitAction(&call_data->context, request, &cq_);
    
    // Request that, upon completion, the reply and status are written to the call_data
    // The tag is the memory address of the call_data object
    call_data->rpc->Finish(&call_data->reply, &call_data->status, (void*)call_data);
    
    pending_requests_.fetch_add(1);
}

void VPRAMAsyncClient::QueryEntityStatus(
    uint64_t entity_id,
    std::function<void(const vpram::EntityStatus&, const grpc::Status&)> callback) {
    
    if (!running_.load()) {
        std::cerr << "VPRAMAsyncClient: Cannot query status - client not running" << std::endl;
        return;
    }
    
    // Create the request
    vpram::EntityQuery query;
    query.set_entity_id(entity_id);
    
    // For simplicity, we'll create a similar structure for entity queries
    // In a production system, you'd want a separate ClientCallData type for each RPC
    struct EntityQueryCallData {
        vpram::EntityStatus reply;
        grpc::ClientContext context;
        grpc::Status status;
        std::unique_ptr<grpc::ClientAsyncResponseReader<vpram::EntityStatus>> rpc;
        std::function<void(const vpram::EntityStatus&, const grpc::Status&)> callback;
    };
    
    auto* call_data = new EntityQueryCallData();
    call_data->callback = std::move(callback);
    
    std::chrono::system_clock::time_point deadline = 
        std::chrono::system_clock::now() + std::chrono::seconds(5);
    call_data->context.set_deadline(deadline);
    
    call_data->rpc = stub_->AsyncQueryEntityStatus(&call_data->context, query, &cq_);
    call_data->rpc->Finish(&call_data->reply, &call_data->status, (void*)call_data);
    
    pending_requests_.fetch_add(1);
}

size_t VPRAMAsyncClient::GetPendingRequestCount() const {
    return pending_requests_.load();
}

void VPRAMAsyncClient::AsyncWorkerThread() {
    void* tag;
    bool ok;
    
    // Main event loop - blocks on Next() until an event is available
    while (cq_.Next(&tag, &ok)) {
        // When ok is false, the completion queue is shutting down
        if (!ok) {
            break;
        }
        
        // The tag is the pointer to our ClientCallData
        auto* call_data = static_cast<ClientCallData*>(tag);
        
        // Invoke the callback with the response and status
        if (call_data->callback) {
            call_data->callback(call_data->reply, call_data->status);
        }
        
        // Clean up the call data
        delete call_data;
        
        pending_requests_.fetch_sub(1);
    }
}

// ActionRequestBuilder implementation
ActionRequestBuilder& ActionRequestBuilder::SetEntityId(uint64_t id) {
    request_.set_entity_id(id);
    return *this;
}

ActionRequestBuilder& ActionRequestBuilder::SetPosition(double x, double y, double z) {
    request_.set_position_x(x);
    request_.set_position_y(y);
    request_.set_position_z(z);
    return *this;
}

ActionRequestBuilder& ActionRequestBuilder::SetKernelType(vpram::KernelType type) {
    request_.set_kernel_type(type);
    return *this;
}

ActionRequestBuilder& ActionRequestBuilder::SetKernelParam(double param) {
    request_.set_kernel_param(param);
    return *this;
}

ActionRequestBuilder& ActionRequestBuilder::AddSparseVectorEntry(uint32_t index, double value) {
    auto* sparse_vec = request_.mutable_sparse_vector();
    sparse_vec->add_indices(index);
    sparse_vec->add_values(value);
    return *this;
}

ActionRequestBuilder& ActionRequestBuilder::SetSparseVectorCapacity(uint32_t capacity) {
    request_.mutable_sparse_vector()->set_capacity(capacity);
    return *this;
}

vpram::ActionRequest ActionRequestBuilder::Build() const {
    return request_;
}

} // namespace vpram
