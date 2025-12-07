#pragma once

#include <grpcpp/grpcpp.h>
#include <memory>
#include <thread>
#include <atomic>
#include <functional>
#include <queue>
#include <mutex>
#include "vpram.grpc.pb.h"

namespace vpram {

/// Callback function type for action completion
using ActionCallback = std::function<void(const vpram::ActionResponse&, const grpc::Status&)>;

/// Per-call context data for asynchronous requests
struct ClientCallData {
    vpram::ActionResponse reply;
    grpc::ClientContext context;
    grpc::Status status;
    std::unique_ptr<grpc::ClientAsyncResponseReader<vpram::ActionResponse>> rpc;
    ActionCallback callback;
    
    ClientCallData(ActionCallback cb) : callback(std::move(cb)) {}
};

/// Asynchronous gRPC client for VPRAM Engine
///
/// This client manages a dedicated background thread that handles gRPC completion
/// events, ensuring that network I/O doesn't block the main game thread.
///
/// Usage:
///   VPRAMAsyncClient client("localhost:50051");
///   client.Start();
///   
///   vpram::ActionRequest request;
///   // ... populate request ...
///   
///   client.SubmitAction(request, [](const auto& response, const auto& status) {
///       if (status.ok()) {
///           // Handle successful response
///       } else {
///           // Handle error
///       }
///   });
///
///   // Later, when shutting down:
///   client.Shutdown();
class VPRAMAsyncClient {
public:
    /// Constructor
    /// @param server_address Address of the VPRAM server (e.g., "localhost:50051")
    explicit VPRAMAsyncClient(const std::string& server_address);
    
    /// Destructor - ensures proper cleanup
    ~VPRAMAsyncClient();
    
    /// Start the async worker thread
    /// Must be called before submitting any actions
    void Start();
    
    /// Shutdown the client and wait for pending operations
    void Shutdown();
    
    /// Submit an action to the VPRAM server (non-blocking)
    /// @param request The action request to submit
    /// @param callback Function to call when the request completes
    void SubmitAction(const vpram::ActionRequest& request, ActionCallback callback);
    
    /// Query entity status (non-blocking)
    /// @param entity_id The ID of the entity to query
    /// @param callback Function to call when the query completes
    void QueryEntityStatus(uint64_t entity_id, 
                          std::function<void(const vpram::EntityStatus&, const grpc::Status&)> callback);
    
    /// Check if the client is currently running
    bool IsRunning() const { return running_.load(); }
    
    /// Get statistics about pending requests
    size_t GetPendingRequestCount() const;

private:
    /// Worker thread function that processes completion queue events
    void AsyncWorkerThread();
    
    /// Process a single completion queue event
    void ProcessCompletionEvent();
    
    std::shared_ptr<grpc::Channel> channel_;
    std::unique_ptr<vpram::HOGSSubmission::Stub> stub_;
    grpc::CompletionQueue cq_;
    std::thread worker_thread_;
    std::atomic<bool> running_{false};
    std::atomic<size_t> pending_requests_{0};
};

/// Helper class for building action requests with a fluent interface
class ActionRequestBuilder {
public:
    ActionRequestBuilder& SetEntityId(uint64_t id);
    ActionRequestBuilder& SetPosition(double x, double y, double z);
    ActionRequestBuilder& SetKernelType(vpram::KernelType type);
    ActionRequestBuilder& SetKernelParam(double param);
    ActionRequestBuilder& AddSparseVectorEntry(uint32_t index, double value);
    ActionRequestBuilder& SetSparseVectorCapacity(uint32_t capacity);
    
    vpram::ActionRequest Build() const;
    
private:
    vpram::ActionRequest request_;
};

} // namespace vpram
