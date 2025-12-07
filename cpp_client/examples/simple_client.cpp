/// Simple C++ Client Example
/// 
/// Demonstrates how to use the VPRAMAsyncClient to submit actions
/// to the VPRAM server without blocking the main thread.

#include "vpram_async_client.h"
#include <iostream>
#include <thread>
#include <chrono>
#include <atomic>

// Counter for tracking completed requests
std::atomic<int> completed_requests{0};

void HandleActionResponse(const vpram::ActionResponse& response, const grpc::Status& status) {
    if (status.ok()) {
        std::cout << "✓ Action completed successfully!" << std::endl;
        std::cout << "  Status: " << vpram::StatusCode_Name(response.status()) << std::endl;
        std::cout << "  Cell ID: " << response.cell_id() << std::endl;
        std::cout << "  Quaternion: [";
        for (int i = 0; i < response.quaternion_size(); ++i) {
            std::cout << response.quaternion(i);
            if (i < response.quaternion_size() - 1) std::cout << ", ";
        }
        std::cout << "]" << std::endl;
        std::cout << "  Execution time: " << response.execution_time_us() << " μs" << std::endl;
        
        if (!response.error_message().empty()) {
            std::cout << "  Warning: " << response.error_message() << std::endl;
        }
    } else {
        std::cerr << "✗ Action failed!" << std::endl;
        std::cerr << "  gRPC Error: " << status.error_message() << std::endl;
    }
    
    completed_requests.fetch_add(1);
    std::cout << std::endl;
}

int main(int argc, char** argv) {
    std::cout << "VPRAM C++ Async Client Example" << std::endl;
    std::cout << "===============================" << std::endl << std::endl;
    
    // Parse server address from command line, or use default
    std::string server_address = "localhost:50051";
    if (argc > 1) {
        server_address = argv[1];
    }
    
    std::cout << "Connecting to VPRAM server at: " << server_address << std::endl;
    
    // Create and start the async client
    vpram::VPRAMAsyncClient client(server_address);
    client.Start();
    
    std::cout << "Client started. Background worker thread is now processing requests." << std::endl;
    std::cout << std::endl;
    
    // Example 1: Submit a single action using the builder pattern
    std::cout << "Example 1: Submitting a Scale action..." << std::endl;
    
    auto request1 = vpram::ActionRequestBuilder()
        .SetEntityId(12345)
        .SetPosition(100.5, 200.7, 300.3)
        .SetKernelType(vpram::KernelType::SCALE)
        .SetKernelParam(1.2)
        .AddSparseVectorEntry(1, 0.5)
        .AddSparseVectorEntry(2, 1.0)
        .AddSparseVectorEntry(3, 0.5)
        .AddSparseVectorEntry(4, 1.0)
        .SetSparseVectorCapacity(10)
        .Build();
    
    client.SubmitAction(request1, HandleActionResponse);
    
    // Example 2: Submit multiple actions rapidly
    std::cout << "Example 2: Submitting multiple actions in rapid succession..." << std::endl;
    
    for (int i = 0; i < 5; ++i) {
        auto request = vpram::ActionRequestBuilder()
            .SetEntityId(20000 + i)
            .SetPosition(150.0 + i * 10, 250.0 + i * 10, 350.0 + i * 10)
            .SetKernelType(vpram::KernelType::SCALE)
            .SetKernelParam(1.0 + i * 0.1)
            .AddSparseVectorEntry(1, 0.5)
            .AddSparseVectorEntry(2, 1.0)
            .SetSparseVectorCapacity(10)
            .Build();
        
        client.SubmitAction(request, HandleActionResponse);
    }
    
    std::cout << std::endl;
    std::cout << "All actions submitted (non-blocking). Main thread continues..." << std::endl;
    std::cout << "Waiting for responses from background thread..." << std::endl;
    std::cout << std::endl;
    
    // The main thread is not blocked! We can do other work here.
    // For this example, we'll just wait for completions.
    
    // Wait for all requests to complete (with timeout)
    int timeout_seconds = 10;
    int expected_completions = 6;  // 1 + 5 from above
    
    for (int i = 0; i < timeout_seconds * 10; ++i) {
        if (completed_requests.load() >= expected_completions) {
            break;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    
    std::cout << "Completed " << completed_requests.load() << " out of " 
              << expected_completions << " requests." << std::endl;
    std::cout << "Pending requests: " << client.GetPendingRequestCount() << std::endl;
    std::cout << std::endl;
    
    // Example 3: Query entity status
    std::cout << "Example 3: Querying entity status..." << std::endl;
    
    client.QueryEntityStatus(12345, [](const vpram::EntityStatus& status, const grpc::Status& grpc_status) {
        if (grpc_status.ok()) {
            std::cout << "✓ Entity status retrieved!" << std::endl;
            std::cout << "  Entity ID: " << status.entity_id() << std::endl;
            std::cout << "  Cell ID: " << status.cell_id() << std::endl;
            std::cout << "  Is Active: " << (status.is_active() ? "Yes" : "No") << std::endl;
        } else {
            std::cerr << "✗ Query failed: " << grpc_status.error_message() << std::endl;
        }
        completed_requests.fetch_add(1);
    });
    
    expected_completions++;
    
    // Wait a bit more for the query to complete
    std::this_thread::sleep_for(std::chrono::seconds(2));
    
    std::cout << std::endl;
    std::cout << "Shutting down client..." << std::endl;
    
    // Shutdown the client (waits for pending requests)
    client.Shutdown();
    
    std::cout << "Client shutdown complete." << std::endl;
    std::cout << std::endl;
    std::cout << "Example finished!" << std::endl;
    
    return 0;
}
