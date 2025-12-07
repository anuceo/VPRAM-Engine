cmake_minimum_required(VERSION 3.15)
project(vpram_cpp_client VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(Threads REQUIRED)
find_package(Protobuf REQUIRED)
find_package(gRPC CONFIG REQUIRED)

# Generate protobuf and gRPC sources
set(PROTO_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../rust/proto")
set(PROTO_FILE "${PROTO_PATH}/vpram.proto")
set(GENERATED_PROTOBUF_PATH "${CMAKE_CURRENT_BINARY_DIR}/generated")

file(MAKE_DIRECTORY ${GENERATED_PROTOBUF_PATH})

# Protobuf generation
set(PROTO_SRCS "${GENERATED_PROTOBUF_PATH}/vpram.pb.cc")
set(PROTO_HDRS "${GENERATED_PROTOBUF_PATH}/vpram.pb.h")

# gRPC generation
set(GRPC_SRCS "${GENERATED_PROTOBUF_PATH}/vpram.grpc.pb.cc")
set(GRPC_HDRS "${GENERATED_PROTOBUF_PATH}/vpram.grpc.pb.h")

add_custom_command(
    OUTPUT ${PROTO_SRCS} ${PROTO_HDRS} ${GRPC_SRCS} ${GRPC_HDRS}
    COMMAND protobuf::protoc
    ARGS --grpc_out=${GENERATED_PROTOBUF_PATH}
         --cpp_out=${GENERATED_PROTOBUF_PATH}
         --plugin=protoc-gen-grpc=$<TARGET_FILE:gRPC::grpc_cpp_plugin>
         -I ${PROTO_PATH}
         ${PROTO_FILE}
    DEPENDS ${PROTO_FILE}
    COMMENT "Generating protobuf and gRPC C++ sources"
)

# Create the client library
add_library(vpram_client
    src/vpram_async_client.cpp
    ${PROTO_SRCS}
    ${GRPC_SRCS}
)

target_include_directories(vpram_client
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<BUILD_INTERFACE:${GENERATED_PROTOBUF_PATH}>
        $<INSTALL_INTERFACE:include>
)

target_link_libraries(vpram_client
    PUBLIC
        gRPC::grpc++
        protobuf::libprotobuf
        Threads::Threads
)

# Example executables
add_executable(simple_client examples/simple_client.cpp)
target_link_libraries(simple_client PRIVATE vpram_client)

add_executable(unreal_integration examples/unreal_integration.cpp)
target_link_libraries(unreal_integration PRIVATE vpram_client)

# Installation rules
install(TARGETS vpram_client
    EXPORT vpram_clientTargets
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
    INCLUDES DESTINATION include
)

install(DIRECTORY include/
    DESTINATION include
)

install(FILES
    ${PROTO_HDRS}
    ${GRPC_HDRS}
    DESTINATION include
)

# Export configuration
install(EXPORT vpram_clientTargets
    FILE vpram_clientTargets.cmake
    NAMESPACE vpram::
    DESTINATION lib/cmake/vpram_client
)

# Print configuration summary
message(STATUS "VPRAM C++ Client Configuration:")
message(STATUS "  C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  Proto file: ${PROTO_FILE}")
message(STATUS "  Generated sources: ${GENERATED_PROTOBUF_PATH}")
