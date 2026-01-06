require "../logging"
require "../mcp_server"

module Pasto
  # Register all utility routes (syntax, cache, MCP)
  def self.register_utility_routes
    base_path = Pasto.config.base_path

    # Serve lexer XML files from tartrazine's baked file system
    get Pasto::PathHelper.with_base_path("/assets/lexers/:filename", base_path) do |env|
      filename = env.params.url["filename"]

      unless filename.ends_with?(".xml")
        env.response.status_code = 400
        next "Invalid file type"
      end

      begin
        # Serve from tartrazine's baked LexerFiles
        lexer_xml = Tartrazine::LexerFiles.get("/lexers/#{filename}").gets_to_end
        env.response.content_type = "text/xml"
        env.response.headers["Cache-Control"] = "public, max-age=604800" # 1 week
        lexer_xml
      rescue ex
        env.response.status_code = 404
        "Lexer not found: #{filename}"
      end
    end

    # Dummy endpoint for tartrazine.js theme loading
    # Themes are already loaded via /syntax endpoint, so we return empty theme data
    get Pasto::PathHelper.with_base_path("/styles/:filename", base_path) do |env|
      filename = env.params.url["filename"]
      if filename.ends_with?(".xml")
        # Return minimal valid XML theme (CSS is already loaded via /syntax endpoint)
        empty_theme = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<theme name="#{filename.gsub(".xml", "")}">
  <settings>
    <setting name="background-color" value="#ffffff"/>
  </settings>
  <styles>
  </styles>
</theme>
XML
        env.response.content_type = "text/xml"
        env.response.headers["Cache-Control"] = "public, max-age=604800"
        empty_theme
      else
        env.response.status_code = 404
        "File not found"
      end
    end

    get Pasto::PathHelper.with_base_path("/syntax/:family/:variant", base_path) do |env|
      family = env.params.url["family"].gsub(/-dark$/, "").gsub(/-light$/, "")
      variant = env.params.url["variant"]
      theme_name = "#{family}/#{variant}"

      begin
        # Use Tartrazine theme CSS for the specified theme and variant
        formatter = Tartrazine::Html.new(theme: Tartrazine.theme(family, variant))
        css = formatter.style_defs

        # Tartrazine CSS is now used directly (tartrazine.js on client, tartrazine on server)
        # No need for highlight.js compatibility layer anymore
        Pasto::Logging.debug("Generating CSS for theme: #{theme_name}")

        env.response.content_type = "text/css"
        env.response.headers["Cache-Control"] = "public, max-age=604800" # 1 week in seconds
        css
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
