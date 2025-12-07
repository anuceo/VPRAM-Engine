# VPRAM Engine Client Integration Guide

Complete guide for integrating the VPRAM Engine with game clients (Unreal Engine, Unity, custom C++ engines).

## Overview

The VPRAM Engine provides a **multi-layer architecture** that enables game clients to leverage high-performance Julia mathematical operations through a safe, async Rust backend:

```
┌─────────────────────────────────────────────────────────────┐
│                    Game Client Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Unreal     │  │    Unity     │  │  Custom C++  │     │
│  │   Engine     │  │    Engine    │  │    Engine    │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          └──────────────────┴──────────────────┘
                             │
                    VPRAMAsyncClient (C++)
                             │
          ┌──────────────────┴──────────────────┐
          │     gRPC Protocol (async)           │
          │     - SubmitAction RPC              │
          │     - QueryEntityStatus RPC         │
          │     - SubmitActionBatch RPC         │
          └──────────────────┬──────────────────┘
                             │
┌─────────────────────────────────────────────────────────────┐
│                    Network Backend (Rust)                   │
│                  ConnectionBroker                           │
│                  gRPC Server (port 50051)                   │
│                  WebSocket Server (port 8080)               │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│              HOGS Scheduler (Rust)                          │
│    Cell-based Spatial Locking | Concurrent Execution       │
└─────────────────────────────┬───────────────────────────────┘
                              │
                     Zero-Copy FFI (C-ABI)
                              │
┌─────────────────────────────────────────────────────────────┐
│               Julia Mathematical Core                       │
│   Sparse Vectors | Brownian Motion | Spatial Indexing      │
│   Quaternion Translation | Non-repeatability Guarantee      │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Start the VPRAM Server

```bash
# Terminal 1: Start Rust backend
cd rust
cargo run --bin vpram-server

# Server starts on:
# - gRPC: localhost:50051
# - WebSocket: localhost:8080
```

### 2. Build C++ Client

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt-get install -y libgrpc++-dev libprotobuf-dev protobuf-compiler-grpc

# Or using vcpkg
vcpkg install grpc protobuf

# Build
cd cpp_client
mkdir build && cd build
cmake ..
cmake --build .
```

### 3. Run Example

```bash
./simple_client localhost:50051
```

## Integration Patterns

### Pattern 1: Unreal Engine AActor Integration

```cpp
// VPRAMGameManager.h
#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "vpram_async_client.h"
#include "VPRAMGameManager.generated.h"

UCLASS()
class YOURGAME_API AVPRAMGameManager : public AActor {
    GENERATED_BODY()

public:
    AVPRAMGameManager();

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
    virtual void Tick(float DeltaTime) override;

public:
    // Submit evolution request for an entity
    UFUNCTION(BlueprintCallable, Category = "VPRAM")
    void EvolveEntity(int64 EntityId, FVector Position, float Fluidity, 
                     float Mass, float Rigidity);

    // Query entity status
    UFUNCTION(BlueprintCallable, Category = "VPRAM")
    void QueryEntityStatus(int64 EntityId);

    // Get number of pending requests (for debugging)
    UFUNCTION(BlueprintPure, Category = "VPRAM")
    int32 GetPendingRequestCount() const;

private:
    std::unique_ptr<vpram::VPRAMAsyncClient> Client;

    UPROPERTY(EditAnywhere, Category = "VPRAM")
    FString ServerAddress = TEXT("localhost:50051");

    // Callback handlers
    void OnEntityEvolved(int64 EntityId, const vpram::ActionResponse& Response,
                        const grpc::Status& Status);
};
```

```cpp
// VPRAMGameManager.cpp
#include "VPRAMGameManager.h"

AVPRAMGameManager::AVPRAMGameManager() {
    PrimaryActorTick.bCanEverTick = true;
}

void AVPRAMGameManager::BeginPlay() {
    Super::BeginPlay();
    
    // Initialize client
    std::string address = TCHAR_TO_UTF8(*ServerAddress);
    Client = std::make_unique<vpram::VPRAMAsyncClient>(address);
    Client->Start();
    
    UE_LOG(LogTemp, Log, TEXT("VPRAM Client connected to %s"), *ServerAddress);
}

void AVPRAMGameManager::EndPlay(const EEndPlayReason::Type EndPlayReason) {
    Super::EndPlay(EndPlayReason);
    
    if (Client) {
        Client->Shutdown();
        UE_LOG(LogTemp, Log, TEXT("VPRAM Client shutdown complete"));
    }
}

void AVPRAMGameManager::Tick(float DeltaTime) {
    Super::Tick(DeltaTime);
    
    // Optional: Monitor pending requests
    if (Client && Client->GetPendingRequestCount() > 100) {
        UE_LOG(LogTemp, Warning, TEXT("High pending VPRAM requests: %zu"),
               Client->GetPendingRequestCount());
    }
}

void AVPRAMGameManager::EvolveEntity(int64 EntityId, FVector Position,
                                     float Fluidity, float Mass, float Rigidity) {
    if (!Client) return;
    
    // Build request
    auto request = vpram::ActionRequestBuilder()
        .SetEntityId(EntityId)
        .SetPosition(Position.X, Position.Y, Position.Z)
        .SetKernelType(vpram::KernelType::SCALE)
        .SetKernelParam(1.1)  // Example: scale by 1.1
        .AddSparseVectorEntry(1, Fluidity)
        .AddSparseVectorEntry(2, Mass)
        .AddSparseVectorEntry(3, Rigidity)
        .SetSparseVectorCapacity(10)
        .Build();
    
    // Submit asynchronously - DOES NOT BLOCK!
    Client->SubmitAction(request, 
        [this, EntityId](const vpram::ActionResponse& response,
                        const grpc::Status& status) {
            OnEntityEvolved(EntityId, response, status);
        });
}

void AVPRAMGameManager::OnEntityEvolved(int64 EntityId,
                                       const vpram::ActionResponse& Response,
                                       const grpc::Status& Status) {
    if (!Status.ok()) {
        UE_LOG(LogTemp, Error, TEXT("Entity %lld evolution failed: %s"),
               EntityId, UTF8_TO_TCHAR(Status.error_message().c_str()));
        return;
    }
    
    if (Response.status() != vpram::StatusCode::SUCCESS) {
        UE_LOG(LogTemp, Warning, TEXT("Entity %lld: %s"),
               EntityId, UTF8_TO_TCHAR(Response.error_message().c_str()));
        return;
    }
    
    // Extract results
    uint64 cell_id = Response.cell_id();
    
    // Quaternion for rendering
    FQuat quaternion(
        Response.quaternion(1),  // X
        Response.quaternion(2),  // Y
        Response.quaternion(3),  // Z
        Response.quaternion(0)   // W
    );
    
    // Update entity in game world
    // (You'd typically broadcast this to the actual entity actor)
    UE_LOG(LogTemp, Log, TEXT("Entity %lld evolved: Cell=%llu, Quat=[%.3f,%.3f,%.3f,%.3f]"),
           EntityId, cell_id, quaternion.X, quaternion.Y, quaternion.Z, quaternion.W);
}

void AVPRAMGameManager::QueryEntityStatus(int64 EntityId) {
    if (!Client) return;
    
    Client->QueryEntityStatus(EntityId,
        [this, EntityId](const vpram::EntityStatus& status,
                        const grpc::Status& grpc_status) {
            if (grpc_status.ok()) {
                UE_LOG(LogTemp, Log, TEXT("Entity %lld status: Cell=%llu, Active=%s"),
                       EntityId, status.cell_id(),
                       status.is_active() ? TEXT("Yes") : TEXT("No"));
            }
        });
}

int32 AVPRAMGameManager::GetPendingRequestCount() const {
    return Client ? static_cast<int32>(Client->GetPendingRequestCount()) : 0;
}
```

### Pattern 2: Unity Native Plugin

```cpp
// vpram_unity_plugin.cpp
// Export C API for Unity's P/Invoke

#include "vpram_async_client.h"
#include <unordered_map>
#include <mutex>

// Global client registry
static std::unordered_map<int, std::unique_ptr<vpram::VPRAMAsyncClient>> g_clients;
static std::mutex g_clients_mutex;
static int g_next_handle = 1;

// Callback type for Unity
typedef void (*UnityCallback)(int64_t entity_id, uint64_t cell_id,
                              double qw, double qx, double qy, double qz,
                              int status_code);

extern "C" {

// Create a client and return a handle
int VPRAM_CreateClient(const char* server_address) {
    std::lock_guard<std::mutex> lock(g_clients_mutex);
    
    int handle = g_next_handle++;
    auto client = std::make_unique<vpram::VPRAMAsyncClient>(server_address);
    client->Start();
    
    g_clients[handle] = std::move(client);
    return handle;
}

// Submit an action
void VPRAM_SubmitAction(int client_handle,
                       int64_t entity_id,
                       double pos_x, double pos_y, double pos_z,
                       int kernel_type,
                       double kernel_param,
                       UnityCallback callback) {
    vpram::VPRAMAsyncClient* client = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_clients_mutex);
        auto it = g_clients.find(client_handle);
        if (it != g_clients.end()) {
            client = it->second.get();
        }
    }
    
    if (!client) return;
    
    auto request = vpram::ActionRequestBuilder()
        .SetEntityId(entity_id)
        .SetPosition(pos_x, pos_y, pos_z)
        .SetKernelType(static_cast<vpram::KernelType>(kernel_type))
        .SetKernelParam(kernel_param)
        .Build();
    
    client->SubmitAction(request,
        [callback, entity_id](const vpram::ActionResponse& response,
                             const grpc::Status& status) {
            if (status.ok() && callback) {
                callback(
                    entity_id,
                    response.cell_id(),
                    response.quaternion(0),
                    response.quaternion(1),
                    response.quaternion(2),
                    response.quaternion(3),
                    static_cast<int>(response.status())
                );
            }
        });
}

// Get pending request count
int VPRAM_GetPendingCount(int client_handle) {
    std::lock_guard<std::mutex> lock(g_clients_mutex);
    auto it = g_clients.find(client_handle);
    if (it != g_clients.end()) {
        return static_cast<int>(it->second->GetPendingRequestCount());
    }
    return 0;
}

// Destroy client
void VPRAM_DestroyClient(int client_handle) {
    std::lock_guard<std::mutex> lock(g_clients_mutex);
    auto it = g_clients.find(client_handle);
    if (it != g_clients.end()) {
        it->second->Shutdown();
        g_clients.erase(it);
    }
}

} // extern "C"
```

```csharp
// Unity C# wrapper
using System;
using System.Runtime.InteropServices;
using UnityEngine;

public class VPRAMClient : MonoBehaviour {
    private int clientHandle = -1;
    
    [DllImport("vpram_unity_plugin")]
    private static extern int VPRAM_CreateClient(string server_address);
    
    [DllImport("vpram_unity_plugin")]
    private static extern void VPRAM_SubmitAction(
        int client_handle,
        long entity_id,
        double pos_x, double pos_y, double pos_z,
        int kernel_type,
        double kernel_param,
        UnityCallback callback
    );
    
    [DllImport("vpram_unity_plugin")]
    private static extern int VPRAM_GetPendingCount(int client_handle);
    
    [DllImport("vpram_unity_plugin")]
    private static extern void VPRAM_DestroyClient(int client_handle);
    
    private delegate void UnityCallback(long entity_id, ulong cell_id,
                                       double qw, double qx, double qy, double qz,
                                       int status_code);
    
    void Start() {
        clientHandle = VPRAM_CreateClient("localhost:50051");
        Debug.Log($"VPRAM Client created: {clientHandle}");
    }
    
    void OnDestroy() {
        if (clientHandle >= 0) {
            VPRAM_DestroyClient(clientHandle);
        }
    }
    
    public void EvolveEntity(long entityId, Vector3 position) {
        if (clientHandle < 0) return;
        
        VPRAM_SubmitAction(
            clientHandle,
            entityId,
            position.x, position.y, position.z,
            1,  // KernelType::SCALE
            1.1,
            OnEntityEvolved
        );
    }
    
    [AOT.MonoPInvokeCallback(typeof(UnityCallback))]
    private static void OnEntityEvolved(long entityId, ulong cellId,
                                       double qw, double qx, double qy, double qz,
                                       int statusCode) {
        Debug.Log($"Entity {entityId} evolved: Cell={cellId}, " +
                 $"Quat=[{qw:F3},{qx:F3},{qy:F3},{qz:F3}]");
    }
    
    void Update() {
        int pending = VPRAM_GetPendingCount(clientHandle);
        if (pending > 100) {
            Debug.LogWarning($"High pending requests: {pending}");
        }
    }
}
```

## Performance Optimization

### Batch Operations

For updating many entities simultaneously, use batch operations:

```cpp
// Instead of individual submissions:
for (const auto& entity : entities) {
    client.SubmitAction(BuildRequest(entity), callback);
}

// Use batching for better throughput:
vpram::ActionBatchRequest batch;
for (const auto& entity : entities) {
    auto* request = batch.add_actions();
    *request = BuildRequest(entity);
}

client.SubmitActionBatch(batch, [](const vpram::ActionBatchResponse& response,
                                   const grpc::Status& status) {
    // Handle all responses
    for (const auto& resp : response.responses()) {
        // Process each result
    }
});
```

### Connection Pooling

For high-throughput scenarios, create multiple client instances:

```cpp
class VPRAMClientPool {
public:
    VPRAMClientPool(const std::string& address, size_t pool_size = 4) {
        for (size_t i = 0; i < pool_size; ++i) {
            auto client = std::make_unique<vpram::VPRAMAsyncClient>(address);
            client->Start();
            clients_.push_back(std::move(client));
        }
    }
    
    vpram::VPRAMAsyncClient* GetClient() {
        // Round-robin or least-pending selection
        return clients_[next_client_++ % clients_.size()].get();
    }
    
private:
    std::vector<std::unique_ptr<vpram::VPRAMAsyncClient>> clients_;
    std::atomic<size_t> next_client_{0};
};
```

## Debugging and Monitoring

### Enable Logging

```cpp
// In your initialization code
void EnableVPRAMLogging() {
    // Set gRPC logging level
    setenv("GRPC_VERBOSITY", "DEBUG", 1);
    setenv("GRPC_TRACE", "all", 1);
}
```

### Monitor Metrics

```cpp
class VPRAMMonitor {
public:
    void LogMetrics(const vpram::VPRAMAsyncClient& client) {
        UE_LOG(LogVPRAM, Display, TEXT("VPRAM Metrics:"));
        UE_LOG(LogVPRAM, Display, TEXT("  Pending: %zu"), client.GetPendingRequestCount());
        UE_LOG(LogVPRAM, Display, TEXT("  Running: %s"), client.IsRunning() ? TEXT("Yes") : TEXT("No"));
    }
};
```

## Troubleshooting

### Issue: Callbacks Never Execute

**Cause**: Worker thread not started or server not running

**Solution**:
```cpp
// Always call Start() after creating client
client.Start();

// Verify server is running
grpcurl -plaintext localhost:50051 list
```

### Issue: "Client not running" Error

**Cause**: Attempting to submit actions before calling Start()

**Solution**:
```cpp
if (client.IsRunning()) {
    client.SubmitAction(request, callback);
}
```

### Issue: Memory Leaks

**Cause**: Not calling Shutdown() before destroying client

**Solution**:
```cpp
// In destructor or cleanup
if (Client) {
    Client->Shutdown();  // Waits for pending requests
}
```

### Issue: Crashes in Callback

**Cause**: Object referenced in callback was destroyed

**Solution**:
```cpp
// Use weak_ptr for object lifetime management
auto weak_this = weak_from_this();
client.SubmitAction(request, [weak_this](const auto& resp, const auto& status) {
    if (auto strong_this = weak_this.lock()) {
        strong_this->ProcessResponse(resp);
    }
});
```

## See Also

- [C++ Client Documentation](cpp_client/README.md)
- [Server API Documentation](rust/SERVER_README.md)
- [Backend Activation Guide](BACKEND_ACTIVATION.md)
- [FFI Integration Details](FFI_INTEGRATION.md)
- [Protobuf Schema](rust/proto/vpram.proto)
