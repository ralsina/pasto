#!/usr/bin/env crystal

require "http/client"
require "json"

# Simple MCP test script for Pasto integration
# This script tests basic MCP connectivity and tool discovery

class MCPTester
  def initialize(@url : String, @api_key : String)
    @client = HTTP::Client.new
    @headers = HTTP::Headers{
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{@api_key}",
    }
  end

  def test_connection
    puts "🔗 Testing MCP connection to #{@url}..."

    # Test initialize
    response = @client.post("#{@url}/mcp", @headers, initialize_request.to_json)

    if response.success?
      result = JSON.parse(response.body)
      if result["result"]?
        puts "✅ MCP server initialized successfully!"
        puts "📋 Server Info: #{result["result"]["serverInfo"]["name"]} v#{result["result"]["serverInfo"]["version"]}"
        return true
      else
        puts "❌ MCP initialization failed:"
        puts JSON.parse(response.body)
        return false
      end
    else
      puts "❌ Failed to connect to MCP server"
      puts "Status: #{response.status_code}"
      puts "Response: #{response.body}"
      return false
    end
  end

  def test_tools_list
    puts "\n🛠️  Testing tools list..."

    response = @client.post("#{@url}/mcp", @headers, tools_list_request.to_json)

    if response.success?
      result = JSON.parse(response.body)
      if result["result"] && result["result"]["tools"]?
        tools = result["result"]["tools"].as_a
        puts "✅ Found #{tools.size} MCP tools:"
        tools.each do |tool|
          puts "  📦 #{tool["name"]}: #{tool["description"]}"
        end
        return true
      else
        puts "❌ Failed to get tools list"
        return false
      end
    else
      puts "❌ Failed to list tools"
      puts "Status: #{response.status_code}"
      return false
    end
  end

  private def initialize_request
    {
      "jsonrpc" => "2.0",
      "id" => "init_test",
      "method" => "initialize",
      "params" => {
        "protocolVersion" => "2024-11-05",
        "capabilities" => {}
      }
    }
  end

  private def tools_list_request
    {
      "jsonrpc" => "2.0",
      "id" => "tools_test",
      "method" => "tools/list",
      "params" => {}
    }
  end
end

# Usage
if ARGV.size < 2
  puts "Usage: crystal test_mcp.cr <pasto-url> <api-key>"
  puts "Example: crystal test_mcp.cr https://pasto.example.com pasto_ak_1234567890abcdef"
  exit 1
end

url = ARGV[0]
api_key = ARGV[1]

tester = MCPTester.new(url, api_key)

puts "🤖 Pasto MCP Integration Test"
puts "=" * 40

success = tester.test_connection
if success
  tester.test_tools_list
  puts "\n✅ MCP integration test completed successfully!"
else
  puts "\n❌ MCP integration test failed!"
  exit 1
end