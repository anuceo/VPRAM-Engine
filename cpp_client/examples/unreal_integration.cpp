/// Unreal Engine Integration Example
///
/// This example shows how to integrate the VPRAMAsyncClient with Unreal Engine's
/// game loop without blocking the main game thread.

#include "vpram_async_client.h"
#include <iostream>
#include <memory>
#include <chrono>

// Mock Unreal Engine actor class for demonstration
class ASpirit {
public:
    int64_t EntityId;
    double PosX, PosY, PosZ;
    double Fluidity, Mass, Rigidity;
    
    // Quaternion for rendering
    double QuatW, QuatX, QuatY, QuatZ;
    
    ASpirit(int64_t id, double x, double y, double z)
        : EntityId(id), PosX(x), PosY(y), PosZ(z),
          Fluidity(0.5), Mass(1.0), Rigidity(0.5),
          QuatW(1.0), QuatX(0.0), QuatY(0.0), QuatZ(0.0) {}
    
    void UpdateQuaternion(const vpram::ActionResponse& response) {
        if (response.quaternion_size() >= 4) {
            QuatW = response.quaternion(0);
            QuatX = response.quaternion(1);
            QuatY = response.quaternion(2);
            QuatZ = response.quaternion(3);
        }
    }
    
    void UpdateAttributes(const vpram::SparseVectorData& vec) {
        for (int i = 0; i < vec.indices_size(); ++i) {
            uint32_t idx = vec.indices(i);
            double val = vec.values(i);
            
            // Map indices to attributes (example mapping)
            if (idx == 1) Fluidity = val;
            else if (idx == 2) Mass = val;
            else if (idx == 3) Rigidity = val;
        }
    }
};

// Mock game manager class
class VPRAMGameManager {
public:
    VPRAMGameManager(const std::string& server_address)
        : client_(server_address) {
        client_.Start();
        std::cout << "VPRAM Game Manager initialized with server: " << server_address << std::endl;
    }
    
    ~VPRAMGameManager() {
        client_.Shutdown();
        std::cout << "VPRAM Game Manager shutdown complete" << std::endl;
    }
    
    // Called from game logic when a spirit's attributes should evolve
    void EvolveSpirit(ASpirit* spirit, double deltaTime) {
        if (!spirit) return;
        
        // Build the action request
        auto request = vpram::ActionRequestBuilder()
            .SetEntityId(spirit->EntityId)
            .SetPosition(spirit->PosX, spirit->PosY, spirit->PosZ)
            .SetKernelType(vpram::KernelType::SCALE)
            .SetKernelParam(1.0 + deltaTime * 0.1)  // Evolve based on delta time
            .AddSparseVectorEntry(1, spirit->Fluidity)
            .AddSparseVectorEntry(2, spirit->Mass)
            .AddSparseVectorEntry(3, spirit->Rigidity)
            .SetSparseVectorCapacity(10)
            .Build();
        
        // Submit the action with a lambda that captures the spirit pointer
        // IMPORTANT: In production, you must ensure the spirit remains valid
        // until the callback executes (use weak pointers or entity IDs)
        client_.SubmitAction(request, [spirit](const vpram::ActionResponse& response, 
                                               const grpc::Status& status) {
            if (status.ok() && response.status() == vpram::StatusCode::SUCCESS) {
                // Update the spirit's quaternion for rendering
                spirit->UpdateQuaternion(response);
                
                // Update the spirit's attributes from the evolved vector
                if (response.has_updated_vector()) {
                    spirit->UpdateAttributes(response.updated_vector());
                }
                
                std::cout << "Spirit " << spirit->EntityId << " evolved successfully" << std::endl;
            } else {
                std::cerr << "Failed to evolve spirit " << spirit->EntityId << ": "
                          << status.error_message() << std::endl;
            }
        });
    }
    
    // Get statistics for monitoring
    size_t GetPendingEvolutions() const {
        return client_.GetPendingRequestCount();
    }
    
private:
    vpram::VPRAMAsyncClient client_;
};

// Simulated game loop
void SimulateGameTick(VPRAMGameManager& manager, ASpirit& spirit, int tick_number) {
    std::cout << "\n=== Game Tick " << tick_number << " ===" << std::endl;
    
    double deltaTime = 0.016;  // ~60 FPS
    
    // Simulate spirit movement
    spirit.PosX += 1.0;
    spirit.PosY += 0.5;
    
    std::cout << "Spirit position: (" << spirit.PosX << ", " << spirit.PosY << ", " 
              << spirit.PosZ << ")" << std::endl;
    
    // Submit evolution request (non-blocking!)
    manager.EvolveSpirit(&spirit, deltaTime);
    
    // The game loop continues immediately - no blocking!
    std::cout << "Game logic continues without waiting for server..." << std::endl;
    std::cout << "Pending evolutions: " << manager.GetPendingEvolutions() << std::endl;
    
    // Simulate other game logic running in parallel
    // (rendering, physics, AI, etc.)
}

int main(int argc, char** argv) {
    std::cout << "VPRAM + Unreal Engine Integration Example" << std::endl;
    std::cout << "==========================================" << std::endl << std::endl;
    
    std::string server_address = "localhost:50051";
    if (argc > 1) {
        server_address = argv[1];
    }
    
    // Initialize the game manager
    VPRAMGameManager manager(server_address);
    
    // Create a spirit actor
    ASpirit spirit(100001, 500.0, 300.0, 200.0);
    
    std::cout << "\nStarting simulated game loop..." << std::endl;
    std::cout << "Each tick submits an evolution request without blocking." << std::endl;
    
    // Simulate several game ticks
    for (int tick = 1; tick <= 5; ++tick) {
        SimulateGameTick(manager, spirit, tick);
        
        // Sleep to simulate frame time (~60 FPS)
        std::this_thread::sleep_for(std::chrono::milliseconds(16));
    }
    
    std::cout << "\n\nWaiting for all evolutions to complete..." << std::endl;
    
    // Wait for pending requests to complete
    int wait_count = 0;
    while (manager.GetPendingEvolutions() > 0 && wait_count < 100) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
        wait_count++;
    }
    
    std::cout << "\nFinal spirit state:" << std::endl;
    std::cout << "  Position: (" << spirit.PosX << ", " << spirit.PosY << ", " 
              << spirit.PosZ << ")" << std::endl;
    std::cout << "  Attributes: Fluidity=" << spirit.Fluidity 
              << ", Mass=" << spirit.Mass 
              << ", Rigidity=" << spirit.Rigidity << std::endl;
    std::cout << "  Quaternion: [" << spirit.QuatW << ", " << spirit.QuatX 
              << ", " << spirit.QuatY << ", " << spirit.QuatZ << "]" << std::endl;
    
    std::cout << "\nExample complete!" << std::endl;
    
    return 0;
}
