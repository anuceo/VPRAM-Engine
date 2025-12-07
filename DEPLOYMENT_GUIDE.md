# VPRAM Engine - Deployment Guide

This guide covers the final steps for deploying the VPRAM Engine in a production environment.

## Prerequisites

- **Rust**: 1.70+ (for Rust backend)
- **Julia**: 1.6+ (for mathematical core)
- **Protocol Buffers**: protoc compiler (for gRPC)
- **C++ Compiler**: GCC 9+ or Clang 10+ (for C++ client)
- **CMake**: 3.15+ (for C++ client build)

## Build Status

✅ **Julia Mathematical Core**: 215 tests passing  
✅ **Rust FFI Layer**: 15 tests passing  
✅ **Networking Dependencies**: All active (tokio, tonic, tokio-tungstenite, prost)  
⏳ **jlrs Integration**: Requires Julia development headers (see below)

---

## 1. Julia Development Setup

### Install Julia

**Linux (Debian/Ubuntu)**:
```bash
# Install Julia
sudo apt-get update
sudo apt-get install julia julia-dev

# Verify installation
julia --version
```

**macOS**:
```bash
brew install julia
```

**Windows**:
Download from https://julialang.org/downloads/

### Build Julia Runtime

```bash
cd runtime
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. -e 'using Pkg; Pkg.test()'
```

**Expected Output**: All 215 tests pass ✅

---

## 2. Rust Backend Setup

### Install Dependencies

```bash
# Install Protocol Buffers compiler
# Debian/Ubuntu:
sudo apt-get install protobuf-compiler

# macOS:
brew install protobuf

# Windows:
choco install protoc
```

### Build Rust Backend

```bash
cd rust

# Development build
cargo build

# Release build (optimized)
cargo build --release

# Run tests
cargo test
```

**Expected Output**: All 15 tests pass ✅

### Activate jlrs (Optional - Production Only)

To enable direct Julia FFI integration:

1. **Install Julia development headers**:
   ```bash
   # Debian/Ubuntu
   sudo apt-get install julia-dev
   
   # macOS (included with julia)
   # Already installed
   ```

2. **Uncomment jlrs dependency** in `rust/Cargo.toml`:
   ```toml
   [dependencies]
   # Change from:
   # jlrs = { version = "0.19" }
   
   # To:
   jlrs = { version = "0.19" }
   ```

3. **Rebuild with Julia FFI**:
   ```bash
   cargo build --release
   ```

**Note**: If you get compilation errors, ensure `JULIA_DIR` environment variable points to your Julia installation:
```bash
export JULIA_DIR=/usr/local/julia  # or your Julia path
cargo build --release
```

---

## 3. C++ Client Setup

### Install Dependencies

```bash
# Install gRPC and Protocol Buffers
# Debian/Ubuntu:
sudo apt-get install libgrpc++-dev libprotobuf-dev protobuf-compiler-grpc

# macOS:
brew install grpc protobuf

# Windows:
vcpkg install grpc protobuf
```

### Build C++ Client

```bash
cd cpp_client
mkdir build && cd build

cmake ..
cmake --build .

# Run examples
./simple_client localhost:50051
./unreal_integration localhost:50051
```

---

## 4. Production Deployment

### Start the Server

```bash
cd rust

# Run in foreground (for testing)
cargo run --bin vpram-server --release

# Run as background service
nohup cargo run --bin vpram-server --release > vpram-server.log 2>&1 &
```

**Server will listen on**:
- gRPC: `0.0.0.0:50051`
- WebSocket: `0.0.0.0:8080`

### Configure Firewall

```bash
# Allow gRPC port
sudo ufw allow 50051/tcp

# Allow WebSocket port
sudo ufw allow 8080/tcp
```

### Systemd Service (Linux)

Create `/etc/systemd/system/vpram-server.service`:

```ini
[Unit]
Description=VPRAM Engine Server
After=network.target

[Service]
Type=simple
User=vpram
WorkingDirectory=/opt/vpram-engine/rust
ExecStart=/usr/bin/cargo run --bin vpram-server --release
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable vpram-server
sudo systemctl start vpram-server
sudo systemctl status vpram-server
```

---

## 5. Verification

### Test Julia Runtime

```bash
cd runtime
julia --project=. test/runtests.jl
```

Expected: 215 tests pass ✅

### Test Rust FFI

```bash
cd rust
cargo test
```

Expected: 15 tests pass ✅

### Test gRPC Server

```bash
# Terminal 1: Start server
cd rust
cargo run --bin vpram-server

# Terminal 2: Run client
cargo run --example grpc_client
```

Expected: Client successfully submits action and receives response ✅

### Test C++ Client

```bash
# Terminal 1: Ensure server is running

# Terminal 2: Run C++ client
cd cpp_client/build
./simple_client localhost:50051
```

Expected: Client submits actions without blocking ✅

---

## 6. Performance Tuning

### Rust Backend

Edit `rust/Cargo.toml` release profile:

```toml
[profile.release]
opt-level = 3              # Maximum optimization
lto = true                 # Link-time optimization
codegen-units = 1          # Single codegen unit for better optimization
strip = true               # Strip symbols (smaller binary)
```

### Julia Precompilation

```bash
cd runtime
julia --project=. -e 'using Pkg; Pkg.precompile()'
```

This creates precompiled versions of modules for faster startup.

### System Tuning

**Increase file descriptor limits** (for high connection count):
```bash
# Add to /etc/security/limits.conf
vpram soft nofile 65536
vpram hard nofile 65536
```

**Optimize TCP settings** (for low latency):
```bash
# Add to /etc/sysctl.conf
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
```

---

## 7. Monitoring

### Check Server Health

```bash
# Check if server is listening
netstat -tulpn | grep 50051

# View recent logs
tail -f vpram-server.log

# Monitor resource usage
htop -p $(pgrep vpram-server)
```

### Performance Metrics

The server tracks:
- Total actions processed
- Average latency per action
- Active client connections
- Memory usage

Access via logging output or implement metrics endpoint.

---

## 8. Troubleshooting

### Issue: "Cannot find protoc"

**Solution**: Install protobuf compiler
```bash
sudo apt-get install protobuf-compiler
```

### Issue: "jl-sys build failed - uv.h not found"

**Solution**: Install Julia development headers
```bash
sudo apt-get install julia-dev
```

Or set `JULIA_DIR`:
```bash
export JULIA_DIR=/usr/local/julia
```

### Issue: "gRPC connection refused"

**Solution**: Ensure server is running and firewall allows connections
```bash
# Check server is running
ps aux | grep vpram-server

# Check port is listening
netstat -tulpn | grep 50051

# Test connection
telnet localhost 50051
```

### Issue: "C++ client compilation fails"

**Solution**: Ensure gRPC development libraries are installed
```bash
# Debian/Ubuntu
sudo apt-get install libgrpc++-dev libprotobuf-dev

# macOS
brew install grpc protobuf
```

---

## 9. Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│              Game Clients (C++)                     │
│  • VPRAMAsyncClient (non-blocking)                  │
│  • Unreal Engine Integration                        │
│  • Unity Native Plugin                              │
└─────────────────┬───────────────────────────────────┘
                  │ gRPC/WebSocket
┌─────────────────▼───────────────────────────────────┐
│         Rust Network Backend                        │
│  • ConnectionBroker (gRPC server)                   │
│  • Entity State Management                          │
│  • WebSocket Broadcasting                           │
└─────────────────┬───────────────────────────────────┘
                  │ Execute Kernel
┌─────────────────▼───────────────────────────────────┐
│         HOGS Scheduler (Rust)                       │
│  • Cell-based spatial locking                       │
│  • Concurrent kernel execution                      │
│  • Thread-safe coordination                         │
└─────────────────┬───────────────────────────────────┘
                  │ Zero-Copy FFI
┌─────────────────▼───────────────────────────────────┐
│         Julia Mathematical Core                     │
│  • Sparse vector operations                         │
│  • Brownian motion evolution                        │
│  • Spatial indexing (Cell IDs)                      │
│  • Quaternion translation                           │
└─────────────────────────────────────────────────────┘
```

---

## 10. Next Steps

Once deployed:

1. **Load Testing**: Use `grpc_bench` or custom load testing tool
2. **Monitoring**: Set up Prometheus/Grafana for metrics
3. **Scaling**: Deploy multiple server instances behind load balancer
4. **Security**: Add TLS/SSL for gRPC connections
5. **Authentication**: Implement token-based auth for clients

---

## Resources

- **Julia Documentation**: https://docs.julialang.org/
- **Rust gRPC (tonic)**: https://github.com/hyperium/tonic
- **gRPC C++**: https://grpc.io/docs/languages/cpp/
- **jlrs Documentation**: https://github.com/Taaitaaiger/jlrs

---

## Support

For issues or questions:
- Check existing documentation in `README.md` and other guides
- Review troubleshooting section above
- Check GitHub issues
- Contact VPRAM Team

---

**Last Updated**: 2025-12-07  
**Status**: Production Ready (jlrs integration optional)
