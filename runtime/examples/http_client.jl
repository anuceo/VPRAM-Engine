#!/usr/bin/env julia
"""
Julia HTTP Client Example
Demonstrates how to use Julia as a "curl" alternative for making HTTP requests.

This shows Julia's HTTP.jl package which provides functionality similar to curl.

To use this, first install HTTP.jl:
  julia> using Pkg; Pkg.add("HTTP")
  julia> using Pkg; Pkg.add("JSON")
"""

"""
Example 1: Simple GET request (like: curl https://example.com)

Usage:
  # Note: HTTP package needs to be installed first
  # julia> using HTTP
  # julia> response = HTTP.get("https://api.github.com")
"""
function simple_get_example()
    println("Simple GET request:")
    println("  using HTTP")
    println("  response = HTTP.get(\"https://api.github.com\")")
    println("  println(response.status)")
    println()
end

"""
Example 2: GET with headers (like: curl -H "User-Agent: MyApp" https://example.com)

Usage:
  # julia> using HTTP
  # julia> headers = [\"User-Agent\" => \"MyApp\"]")
  # julia> response = HTTP.get(url, headers)")
"""
function get_with_headers_example()
    println("GET with custom headers:")
    println("  using HTTP")
    println("  headers = [\"User-Agent\" => \"VPRAM-Engine/1.0\",")
    println("             \"Accept\" => \"application/json\"]")
    println("  response = HTTP.get(url, headers)")
    println()
end

"""
Example 3: POST request (like: curl -X POST -d '{"key":"value"}' https://example.com/api)

Usage:
  # julia> using HTTP, JSON
  # julia> data = Dict("key" => "value")
  # julia> headers = ["Content-Type" => "application/json"]
  # julia> response = HTTP.post(url, headers, JSON.json(data))
"""
function post_json_example()
    println("POST JSON data:")
    println("  using HTTP, JSON")
    println("  data = Dict(\"key\" => \"value\")")
    println("  headers = [\"Content-Type\" => \"application/json\"]")
    println("  response = HTTP.post(url, headers, JSON.json(data))")
    println()
end

"""
Example 4: Download file (like: curl -O https://example.com/file.txt)

Usage:
  # julia> using HTTP
  # julia> HTTP.download("https://example.com/file.txt", "output.txt")
"""
function download_file_example()
    println("Download file:")
    println("  using HTTP")
    println("  HTTP.download(\"https://example.com/file.txt\", \"output.txt\")")
    println()
end

"""
Example 5: gRPC-style request to VPRAM server

Usage:
  # julia> using HTTP, JSON
  # julia> action_data = Dict(...)
  # julia> response = HTTP.post(url, headers, JSON.json(action_data))
"""
function vpram_submit_action_example()
    println("Submit action to VPRAM gRPC server:")
    println("  using HTTP, JSON")
    println("  url = \"http://localhost:50051/vpram.HOGSSubmission/SubmitAction\"")
    println("  action_data = Dict(")
    println("      \"entity_id\" => 12345,")
    println("      \"position\" => Dict(\"x\" => 100.5, \"y\" => 200.7, \"z\" => 300.3),")
    println("      \"kernel_type\" => 1,  # SCALE")
    println("      \"parameter\" => 1.2")
    println("  )")
    println("  response = HTTP.post(url, headers, JSON.json(action_data))")
    println()
end

# Main execution
if abspath(PROGRAM_FILE) == @__FILE__
    println("=" ^ 70)
    println("Julia HTTP Client Examples (Julia as 'curl')")
    println("=" ^ 70)
    println()
    
    println("✓ Julia can make HTTP requests using HTTP.jl package")
    println("✓ Julia version: ", VERSION)
    println()
    
    println("Example Commands:")
    println("-" ^ 70)
    println()
    
    println("1. Simple GET request:")
    println("   julia> using HTTP")
    println("   julia> response = HTTP.get(\"https://api.github.com\")")
    println()
    
    println("2. GET with headers:")
    println("   julia> headers = [\"User-Agent\" => \"MyApp\"]")
    println("   julia> response = HTTP.get(url, headers)")
    println()
    
    println("3. POST JSON data:")
    println("   julia> using HTTP, JSON")
    println("   julia> data = Dict(\"key\" => \"value\")")
    println("   julia> response = HTTP.post(url, [\"Content-Type\" => \"application/json\"], JSON.json(data))")
    println()
    
    println("4. Download file:")
    println("   julia> HTTP.download(\"https://example.com/file.txt\", \"output.txt\")")
    println()
    
    println("5. Call VPRAM gRPC server:")
    println("   julia> vpram_submit_action(\"localhost\", 50051)")
    println()
    
    println("=" ^ 70)
    println("Installation:")
    println("  julia> using Pkg; Pkg.add(\"HTTP\")")
    println("  julia> using Pkg; Pkg.add(\"JSON\")") 
    println("=" ^ 70)
    println()
    println("Yes, you can 'curl' with Julia! ✓")
end
