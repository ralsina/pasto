require "./logging"

module Pasto
  # API documentation page
  get "/api-docs" do |env|
    env.redirect "/assets/api-docs.html"
  end

  # Dynamic OpenAPI specification
  get "/openapi.yaml" do |env|
    # Determine the base URL from the current request
    host = env.request.headers["Host"]? || "localhost:5000"

    # Check if we're behind a reverse proxy with HTTPS
    scheme = "http"
    if proto = env.request.headers["X-Forwarded-Proto"]?
      scheme = proto
    elsif env.request.headers["X-Forwarded-SSL"]? == "on"
      scheme = "https"
    end

    base_url = "#{scheme}://#{host}" # ameba:disable Lint/UselessAssign

    env.response.content_type = "application/x-yaml"
    render "src/views/openapi.yaml.ecr"
  end

  # CORS middleware for API endpoints (must run first)
  before_all do |env|
    # Only apply to API routes
    if env.request.path.starts_with?("/api/")
      # Handle preflight OPTIONS requests
      continue = Pasto::Filters.handle_cors_preflight(env)
      unless continue
        next # Skip further processing for OPTIONS requests
      end

      # Add CORS headers to all API responses
      Pasto::Filters.add_cors_headers(env)
    end
  end

  # API endpoints for lazy loading select options
  get "/api/languages" do |env|
    env.response.content_type = "application/json"

    languages = [{"name" => "Auto", "value" => ""}]

    # Get all available lexers from Tartrazine
    Tartrazine.lexers.sort.each do |lexer|
      languages << {"name" => lexer, "value" => lexer.downcase}
    end

    languages.to_json
  end

  get "/api/themes" do |env|
    env.response.content_type = "application/json"

    # Get only themes that have light/dark variants from Tartrazine
    themes = Tartrazine.themes_with_variants_only.map do |theme|
      {
        name:      theme[:name],
        has_light: theme[:has_light],
        has_dark:  theme[:has_dark],
      }
    end
    themes.sort_by { |theme| theme[:name] }.to_json
  end

  # Generate QR code for a paste (returns PNG image)
  # Note: This endpoint doesn't validate the paste - it just generates a QR code for the URL
  get "/api/qr/:id" do |env|
    env.response.content_type = "image/png"

    id = env.params.url["id"]

    # Get base URL from request or use default
    scheme = env.request.headers["X-Forwarded-Proto"]? || "http"
    host = env.request.headers["X-Forwarded-Host"]? || env.request.headers["Host"]? || "localhost"
    base_url = "#{scheme}://#{host}"

    # Add port if non-standard
    server_port = Kemal.config.port
    if server_port && server_port != 80 && server_port != 443
      base_url += ":#{server_port}"
    end

    # Generate QR code PNG (simple URL encoder - no validation needed)
    qr = QRCode.new("#{base_url}/#{id}")
    png_bytes = qr.as_png(size: 256)

    if png_bytes.empty?
      env.response.status_code = 500
      next "Failed to generate QR code"
    end

    # Set content length explicitly
    env.response.content_length = png_bytes.size

    # Write binary data directly to response
    env.response.write(png_bytes)
  end

  # ============================================================================
  # PASTO REST API v1
  # ============================================================================

  # API v1 base path - require authentication for all endpoints
  before_all do |env|
    if env.request.path.starts_with?("/api/v1/")
      next unless Pasto::Filters.apply_api_auth(env)
    end
  end

  # GET /api/v1/me - Get current user information
  get "/api/v1/me" do |env|
    env.response.content_type = "application/json"

    api_user = Pasto::Filters.get_api_user_from_context(env)
    unless api_user
      env.response.status_code = 401
      next {
        "error"   => "Unauthorized",
        "message" => "User not found",
      }.to_json
    end

    {
      "id"             => api_user.sepia_id,
      "name"           => api_user.name,
      "display_name"   => api_user.display_name,
      "created_at"     => api_user.created_at.to_rfc3339,
      "pico_theme"     => api_user.pico_theme,
      "pico_color"     => api_user.pico_color,
      "syntax_theme"   => api_user.syntax_theme,
      "api_keys_count" => api_user.api_keys.size,
      "pastes_count"   => api_user.all_pastes.size,
    }.to_json
  end

  # GET /api/v1/pastes - List user's pastes
  get "/api/v1/pastes" do |env|
    env.response.content_type = "application/json"

    api_user = Pasto::Filters.get_api_user_from_context(env)
    unless api_user
      env.response.status_code = 401
      next {
        "error"   => "Unauthorized",
        "message" => "User not found",
      }.to_json
    end

    # Pagination parameters
    page = (env.params.query["page"]?.try(&.to_i) || 1).clamp(1, 1000)
    limit = (env.params.query["limit"]?.try(&.to_i) || 20).clamp(1, 100)
    offset = (page - 1) * limit

    pastes = api_user.all_pastes
    total = pastes.size

    # Apply pagination
    paginated_pastes = pastes[offset, limit] || [] of Pasto::Paste

    {
      "pastes" => paginated_pastes.map do |paste|
        {
          "id"                 => paste.sepia_id,
          "title"              => paste.display_title,
          "language"           => paste.language,
          "created_at"         => paste.created_at.to_rfc3339,
          "private"            => paste.private?,
          "encrypted"          => paste.is_encrypted?,
          "burn_after_reading" => paste.burn_after_reading?,
          "size"               => paste.content.bytesize,
        }
      end,
      "pagination" => {
        "page"  => page,
        "limit" => limit,
        "total" => total,
        "pages" => (total.to_f / limit).ceil.to_i,
      },
    }.to_json
  end

  # POST /api/v1/pastes - Create a new paste
  post "/api/v1/pastes" do |env|
    env.response.content_type = "application/json"

    api_user = Pasto::Filters.get_api_user_from_context(env)
    unless api_user
      env.response.status_code = 401
      next {
        "error"   => "Unauthorized",
        "message" => "User not found",
      }.to_json
    end

    # Parse request body
    begin
      body = env.request.body.as(IO).gets_to_end
      if body.empty?
        env.response.status_code = 400
        next {
          "error"   => "Bad Request",
          "message" => "Request body cannot be empty",
        }.to_json
      end

      data = Hash(String, JSON::Any).from_json(body)
    rescue ex : JSON::ParseException
      env.response.status_code = 400
      next {
        "error"   => "Bad Request",
        "message" => "Invalid JSON: #{ex.message}",
      }.to_json
    rescue ex
      env.response.status_code = 400
      next {
        "error"   => "Bad Request",
        "message" => "Failed to read request body",
      }.to_json
    end

    # Extract paste data
    content = data["content"]?.try(&.as_s) || ""
    if content.empty?
      env.response.status_code = 400
      next {
        "error"   => "Bad Request",
        "message" => "Content is required",
      }.to_json
    end

    title = data["title"]?.try(&.as_s)
    language = data["language"]?.try(&.as_s)
    filename = data["filename"]?.try(&.as_s)
    is_private = data["private"]?.try(&.as_bool) || false
    is_encrypted = data["encrypted"]?.try(&.as_bool) || false
    burn_after_reading = data["burn_after_reading"]?.try(&.as_bool) || false

    # Validate content size
    max_size = 1024 * 1024 # 1MB
    if content.bytesize > max_size
      env.response.status_code = 413
      next {
        "error"   => "Content Too Large",
        "message" => "Maximum content size is #{max_size} bytes",
      }.to_json
    end

    # Create paste using API user's SSH key
    ssh_key = api_user.keys.first?
    unless ssh_key
      env.response.status_code = 403
      next {
        "error"   => "Forbidden",
        "message" => "You need an SSH key to create pastes",
      }.to_json
    end

    begin
      paste = ssh_key.create_paste(
        content: content,
        theme: api_user.syntax_theme || "default",
        language: language,
        filename: filename,
        title: title,
        encrypted: is_encrypted
      )

      # Set additional properties
      paste.private = is_private
      paste.burn_after_reading = burn_after_reading
      paste.user_id = api_user.sepia_id

      # Save paste
      unless paste.save
        env.response.status_code = 500
        next {
          "error"   => "Internal Server Error",
          "message" => "Failed to save paste",
        }.to_json
      end

      # Build URL
      host = env.request.headers["Host"]? || "localhost:3000"
      scheme = env.request.headers["X-Forwarded-Proto"]? || "http"
      paste_url = "#{scheme}://#{host}/#{paste.sepia_id}"

      env.response.status_code = 201
      {
        "id"                 => paste.sepia_id,
        "title"              => paste.display_title,
        "language"           => paste.language,
        "created_at"         => paste.created_at.to_rfc3339,
        "private"            => paste.private?,
        "encrypted"          => paste.is_encrypted?,
        "burn_after_reading" => paste.burn_after_reading?,
        "url"                => paste_url,
        "raw_url"            => "#{paste_url}/raw",
      }.to_json
    rescue ex
      Pasto::Logging.error("API: Failed to create paste: #{ex.message}")
      env.response.status_code = 500
      {
        "error"   => "Internal Server Error",
        "message" => "Failed to create paste",
      }.to_json
    end
  end

  # GET /api/v1/pastes/:id - Get specific paste details
  get "/api/v1/pastes/:id" do |env|
    env.response.content_type = "application/json"

    api_user = Pasto::Filters.get_api_user_from_context(env)
    unless api_user
      env.response.status_code = 401
      next {
        "error"   => "Unauthorized",
        "message" => "User not found",
      }.to_json
    end

    id = env.params.url["id"]

    # Load paste
    begin
      paste = Pasto::Paste.from_file(id)
    rescue
      env.response.status_code = 404
      next {
        "error"   => "Not Found",
        "message" => "Paste not found",
      }.to_json
    end

    if paste.nil?
      env.response.status_code = 404
      next {
        "error"   => "Not Found",
        "message" => "Paste not found",
      }.to_json
    end

    # Check access permissions
    if paste.private? && paste.user_id != api_user.sepia_id
      env.response.status_code = 403
      next {
        "error"   => "Forbidden",
        "message" => "This paste is private",
      }.to_json
    end

    {
      "id"                 => paste.sepia_id,
      "title"              => paste.display_title,
      "content"            => paste.content,
      "filename"           => paste.filename,
      "language"           => paste.language,
      "theme"              => paste.theme,
      "created_at"         => paste.created_at.to_rfc3339,
      "updated_at"         => paste.updated_at.to_rfc3339,
      "expires_at"         => paste.expires_at.to_rfc3339,
      "private"            => paste.private?,
      "encrypted"          => paste.is_encrypted?,
      "burn_after_reading" => paste.burn_after_reading?,
      "size"               => paste.content.bytesize,
      "user_id"            => paste.user_id,
      "is_owner"           => paste.user_id == api_user.sepia_id,
      "ssh_fingerprint"    => paste.ssh_fingerprint,
      "ssh_ip"             => paste.ssh_ip,
      "base_id"            => paste.base_id,
      "generation"         => paste.generation,
      "url"                => "#{env.request.headers["X-Forwarded-Proto"]? || "http"}://#{env.request.headers["Host"]? || "localhost:3000"}/#{paste.sepia_id}",
      "raw_url"            => "#{env.request.headers["X-Forwarded-Proto"]? || "http"}://#{env.request.headers["Host"]? || "localhost:3000"}/#{paste.sepia_id}/raw",
    }.to_json
  end

  # GET /api/v1/pastes/:id/content - Get paste content
  get "/api/v1/pastes/:id/content" do |env|
    env.response.content_type = "text/plain"

    api_user = Pasto::Filters.get_api_user_from_context(env)
    unless api_user
      env.response.status_code = 401
      next {
        "error"   => "Unauthorized",
        "message" => "User not found",
      }.to_json
    end

    id = env.params.url["id"]

    # Load paste
    begin
      paste = Pasto::Paste.from_file(id)
    rescue
      halt env, 404
    end

    if paste.nil?
      halt env, 404
    end

    # Check access permissions
    if paste.private? && paste.user_id != api_user.sepia_id
      env.response.status_code = 403
      next "This paste is private"
    end

    # Return content (encrypted or regular)
    if paste.is_encrypted? && paste.responds_to?(:encrypted_content) && paste.encrypted_content
      paste.encrypted_content
    else
      paste.content
    end
  end

  # PATCH /api/v1/pastes/:id - Update a paste (owner only)
  patch "/api/v1/pastes/:id" do |env|
    env.response.content_type = "application/json"

    api_user = Pasto::Filters.get_api_user_from_context(env)
    unless api_user
      env.response.status_code = 401
      next {
        "error"   => "Unauthorized",
        "message" => "User not found",
      }.to_json
    end

    id = env.params.url["id"]

    # Load paste
    begin
      paste = Pasto::Paste.from_file(id)
    rescue
      env.response.status_code = 404
      next {
        "error"   => "Not Found",
        "message" => "Paste not found",
      }.to_json
    end

    if paste.nil?
      env.response.status_code = 404
      next {
        "error"   => "Not Found",
        "message" => "Paste not found",
      }.to_json
    end

    # Check if user is the owner (only owners can update)
    if paste.user_id != api_user.sepia_id
      env.response.status_code = 403
      next {
        "error"   => "Forbidden",
        "message" => "You don't have permission to update this paste",
      }.to_json
    end

    # Parse request body
    request_body = env.request.body
    if request_body.nil?
      env.response.status_code = 400
      next {
        "error"   => "Bad Request",
        "message" => "Request body is required",
      }.to_json
    end

    begin
      # Read and parse JSON body
      body_content = request_body.gets_to_end
      if body_content.empty?
        env.response.status_code = 400
        next {
          "error"   => "Bad Request",
          "message" => "Request body cannot be empty",
        }.to_json
      end

      update_data = JSON.parse(body_content).as_h

      # Validate that content field exists
      unless update_data.has_key?("content")
        env.response.status_code = 400
        next {
          "error"   => "Bad Request",
          "message" => "Content field is required",
        }.to_json
      end

      new_content = update_data["content"].as_s?
      if new_content.nil?
        env.response.status_code = 400
        next {
          "error"   => "Bad Request",
          "message" => "Content must be a string",
        }.to_json
      end

      if new_content.empty?
        env.response.status_code = 400
        next {
          "error"   => "Bad Request",
          "message" => "Content cannot be empty",
        }.to_json
      end

      # Update paste content
      paste.content = new_content

      # Save the updated paste
      if paste.save
        # Return updated paste data
        {
          "id"                 => paste.sepia_id,
          "title"              => paste.display_title,
          "language"           => paste.language,
          "created_at"         => paste.created_at.to_rfc3339,
          "updated_at"         => paste.updated_at.to_rfc3339,
          "private"            => paste.private?,
          "encrypted"          => paste.is_encrypted?,
          "burn_after_reading" => paste.burn_after_reading?,
          "size"               => paste.content.bytesize,
          "is_owner"           => true,
          "url"                => "#{env.request.headers["X-Forwarded-Proto"]? || "http"}://#{env.request.headers["Host"]? || "localhost:3000"}/#{paste.sepia_id}",
          "raw_url"            => "#{env.request.headers["X-Forwarded-Proto"]? || "http"}://#{env.request.headers["Host"]? || "localhost:3000"}/#{paste.sepia_id}/raw",
        }.to_json
      else
        env.response.status_code = 500
        {
          "error"   => "Internal Server Error",
          "message" => "Failed to update paste",
        }.to_json
      end
    rescue JSON::ParseException
      env.response.status_code = 400
      {
        "error"   => "Bad Request",
        "message" => "Invalid JSON in request body",
      }.to_json
    rescue ex
      env.response.status_code = 500
      {
        "error"   => "Internal Server Error",
        "message" => "An unexpected error occurred: #{ex.message}",
      }.to_json
    end
  end

  # DELETE /api/v1/pastes/:id - Delete a paste (owner only)
  delete "/api/v1/pastes/:id" do |env|
    env.response.content_type = "application/json"

    api_user = Pasto::Filters.get_api_user_from_context(env)
    unless api_user
      env.response.status_code = 401
      next {
        "error"   => "Unauthorized",
        "message" => "User not found",
      }.to_json
    end

    id = env.params.url["id"]

    # Load paste
    begin
      paste = Pasto::Paste.from_file(id)
    rescue
      env.response.status_code = 404
      next {
        "error"   => "Not Found",
        "message" => "Paste not found",
      }.to_json
    end

    if paste.nil?
      env.response.status_code = 404
      next {
        "error"   => "Not Found",
        "message" => "Paste not found",
      }.to_json
    end

    # Check ownership
    if paste.user_id != api_user.sepia_id
      env.response.status_code = 403
      next {
        "error"   => "Forbidden",
        "message" => "Only paste owners can delete pastes",
      }.to_json
    end

    # Delete the paste
    begin
      paste.delete
      {
        "message" => "Paste deleted successfully",
      }.to_json
    rescue ex
      Pasto::Logging.error("API: Failed to delete paste: #{ex.message}")
      env.response.status_code = 500
      {
        "error"   => "Internal Server Error",
        "message" => "Failed to delete paste",
      }.to_json
    end
  end
end
