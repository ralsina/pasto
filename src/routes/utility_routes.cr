require "../logging"
require "../mcp_server"

module Pasto
  # Register all utility routes (syntax, cache, MCP)
  def self.register_utility_routes
    base_path = Pasto.config.base_path

    get Pasto::PathHelper.with_base_path("/syntax/:family/:variant", base_path) do |env|
      family = env.params.url["family"].gsub(/-dark$/, "").gsub(/-light$/, "")
      variant = env.params.url["variant"]
      theme_name = "#{family}/#{variant}"

      begin
        # Use Tartrazine theme CSS for the specified theme and variant
        formatter = Tartrazine::Html.new(theme: Tartrazine.theme(family, variant))
        css = formatter.style_defs

        # Add highlight.js classes for compatibility with CodeJar editor
        Pasto::Logging.debug("Generating CSS for theme: #{theme_name}")
        enhanced_css = Pasto.add_highlightjs_classes(css, theme_name)

        env.response.content_type = "text/css"
        env.response.headers["Cache-Control"] = "public, max-age=604800" # 1 week in seconds
        enhanced_css
      rescue ex
        env.response.status_code = 404
        env.response.content_type = "text/plain"
        "Theme not found: #{theme_name}"
      end
    end

    # Cache test endpoint for testing middleware caching
    get Pasto::PathHelper.with_base_path("/api/cache-test", base_path) do |_|
      timestamp = Time.utc.to_unix_ms
      response_body = "Cache test timestamp: #{timestamp}"
      response_body
    end

    # MCP (Model Context Protocol) endpoints for AI assistant integration
    # POST /mcp handles JSON-RPC 2.0 requests
    post Pasto::PathHelper.with_base_path("/mcp", base_path) do |env|
      # Add CORS headers for API endpoints
      Filters.add_cors_headers(env)

      # Create MCP handler with authentication
      handler = Pasto.create_mcp_handler

      begin
        # Handle the MCP request
        handler.handle_post(env)
      rescue ex
        # Log the error and return a generic error response
        Pasto::Logging.error("MCP request error: #{ex.message}")
        env.response.status_code = 500
        env.response.content_type = "application/json"
        {
          "jsonrpc" => "2.0",
          "error"   => {
            "code"    => -32603,
            "message" => "Internal error",
          },
          "id" => nil,
        }.to_json
      end
    end

    # GET /mcp handles Server-Sent Events for real-time communication
    get Pasto::PathHelper.with_base_path("/mcp", base_path) do |env|
      # Add CORS headers for API endpoints
      Filters.add_cors_headers(env)

      # Create MCP handler with authentication
      handler = Pasto.create_mcp_handler

      begin
        # Handle the MCP SSE connection
        handler.handle_get(env)
      rescue ex
        # Log the error
        Pasto::Logging.error("MCP SSE connection error: #{ex.message}")
        # The connection will be closed automatically
      end
    end
  end
end
