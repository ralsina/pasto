require "kemal"
require "http"
require "file_utils"
require "tartrazine"
require "ecr"
require "kemal-session"
require "qr-code"
require "qr-code/export/png"
require "stumpy_png"
require "./filters"
require "./paste"
require "./preview_generator"
require "./user_session"
require "./models/user"
require "./assets"
require "./help"
require "./health"
require "./ratelimit"
require "./cache"
require "./profile"
require "./models/auth_token"
require "./models/ssh_key"
require "./models/api_key"
require "./qr_generator"

module Pasto
  # Helper to validate session and get current user
  def self.get_current_user(env) : User?
    user_session = env.session.object?("user").as(Pasto::UserSession?)

    return nil unless user_session

    # Get user from database
    User.find(user_session.user_id)
  end

  # Unified access control result
  struct AccessResult
    property? allowed : Bool
    property paste : Pasto::Paste?
    property reason : String?
    property status_code : Int32

    def initialize(@allowed : Bool, @paste : Pasto::Paste? = nil, @reason : String? = nil, @status_code : Int32 = 200)
    end

    def success? : Bool
      @allowed && @paste != nil
    end
  end

  # Unified access control helper for paste content access
  # Handles existence, expiration, private status, and burn-after-reading checks
  def self.validate_paste_access(env, require_owner : Bool = false, allow_raw_encrypted : Bool = false) : AccessResult
    id = extract_paste_id(env)

    return AccessResult.new(false, reason: "Invalid paste ID", status_code: 400) if id.nil? || id.empty?

    # Load the paste
    begin
      paste = Pasto::Paste.from_file(id)
      return AccessResult.new(false, reason: "Paste not found", status_code: 404) if paste.nil?
    rescue
      return AccessResult.new(false, reason: "Paste not found", status_code: 404)
    end

    # Get current user for private/owner checks
    current_user = get_current_user(env)
    current_user_id = current_user.try(&.sepia_id)

    # Check ownership requirement
    if require_owner && paste.user_id != current_user_id
      return AccessResult.new(false, paste: paste, reason: "You don't have permission to access this paste", status_code: 403)
    end

    # Check private paste access
    if paste.private? && paste.user_id != current_user_id
      return AccessResult.new(false, paste: paste, reason: "This paste is private and can only be accessed by the owner", status_code: 403)
    end

    # No special handling needed for burn-after-reading in middleware
    # The route handlers will delete the paste after serving content

    # For encrypted pastes in raw endpoints, allow access to encrypted content
    if allow_raw_encrypted && paste.is_encrypted? && paste.responds_to?(:encrypted_content) && paste.encrypted_content
      return AccessResult.new(true, paste: paste)
    end

    # Access granted
    AccessResult.new(true, paste: paste)
  end

  # Extract paste ID from various URL patterns
  private def self.extract_paste_id(env) : String?
    path = env.request.path

    # Handle different route patterns
    if path.includes?("/api/qr/")
      # /api/qr/:id
      env.params.url["id"]?
    elsif path.includes?("/preview/")
      # /preview/:id.png
      id_with_ext = env.params.url["id"]?
      return id_with_ext.gsub(/\.png$/, "") if id_with_ext
    elsif path.includes?("/raw")
      # /:id/raw
      env.params.url["id"]?
    elsif path.includes?("/edit") || path.includes?("/delete") || path.includes?("/fork") || path.includes?("/history")
      # /:id/edit, /:id/delete, /:id/fork, /:id/history
      env.params.url["id"]?
    elsif path.includes?("/version/")
      # /:id/version/:gen - extract base ID
      env.params.url["id"]?
    else
      # Main paste view /:id (with optional extension)
      id = env.params.url["id"]?

      # Handle file extensions in paste IDs (like /:id.py)
      if id && path.includes?(".") && path.count('.') > 0
        parts = path.split(".")
        if parts.size >= 2
          # Extract the part before the last extension
          base_path = path[1..-1] # Remove leading /
          ext_parts = base_path.split(".")
          return ext_parts[0..-2].join(".")
        end
      end

      id
    end
  end

  # /help endpoint: render the help markdown using the ECR template

  # Helper to extract client IP from request
  def self.get_client_ip(env) : String
    if forwarded = env.request.headers["X-Forwarded-For"]?
      forwarded.split(",")[0].strip
    elsif real_ip = env.request.headers["X-Real-IP"]?
      real_ip
    else
      env.request.remote_address.to_s.split(":")[0]
    end
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

  # Apply security headers and rate limiting to all requests
  before_all do |env|
    Pasto::Filters.add_security_headers(env)
    next unless Pasto::Filters.apply_rate_limiting(env)
  end

  # Handle burn-after-reading pastes after response is sent
  after_all do |env|
    Pasto::Filters.handle_burn_after_reading(env)
  end

  # Unified access control filters for paste content endpoints

  # Apply access control to all GET routes that might access paste content
  before_get do |env|
    next unless Pasto::Filters.apply_paste_access_control(env)
  end

  # Apply access control to POST routes for paste management
  before_post do |env|
    path = env.request.path

    # Only apply to paste management routes
    unless path.includes?("/edit") || path.includes?("/delete") || path.includes?("/fork")
      next
    end

    # Determine access requirements
    if path.includes?("/fork")
      # Fork doesn't require ownership, just login
      current_user = Pasto.get_current_user(env)
      unless current_user
        env.response.status_code = 401
        next "You must be logged in to fork a paste"
      end
      # Validate the original paste exists and is accessible
      access_result = Pasto.validate_paste_access(env, require_owner: false)
      unless access_result.success?
        if access_result.status_code == 404
          halt env, 404
        else
          env.response.status_code = access_result.status_code
          next access_result.reason || "Access denied"
        end
      end
    else
      # edit and delete require ownership
      access_result = Pasto.validate_paste_access(env, require_owner: true)
      unless access_result.success?
        if access_result.status_code == 404
          halt env, 404
        else
          env.response.status_code = access_result.status_code
          next access_result.reason || "Access denied"
        end
      end
    end
  end

  # Logout route - clear session
  post "/logout" do |env|
    # Clear the session using kemal-session
    env.session.destroy

    puts "User logged out"

    env.redirect "/?logout=success"
  end

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

    base_url = "#{scheme}://#{host}"

    env.response.content_type = "application/x-yaml"
    render "src/views/openapi.yaml.ecr"
  end

  # Main page - paste creation form
  get "/" do |env|
    # Validate session to get current user
    current_user = Pasto.get_current_user(env)

    # Get theme preferences with priority: user config > cookie > defaults
    saved_pico_theme = current_user.try(&.pico_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
    saved_pico_color = current_user.try(&.pico_color) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
    saved_syntax_theme = current_user.try(&.syntax_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default"

    # Resolve "auto" theme to prevent flashing - default to dark for server-side
    resolved_pico_theme = saved_pico_theme == "auto" ? "dark" : saved_pico_theme

    # Resolve "auto" theme to prevent flashing - default to dark for server-side
    resolved_pico_theme = saved_pico_theme == "auto" ? "dark" : saved_pico_theme

    # Compute CSS file names for template
    pico_theme_file = saved_pico_color == "css" ? "pico.min.css" : "pico.#{saved_pico_color}.min.css"
    syntax_theme_file = "#{saved_syntax_theme}.min.css"

    # Check for login/logout messages
    login_message = env.params.query["login"]? == "success"
    logout_message = env.params.query["logout"]? == "success"

    # Set template variables (ECR template will have access to these)
    is_home_page = true
    page_title = "Pasto"
    pico_theme = saved_pico_theme # Keep original for JavaScript
    pico_color = saved_pico_color
    syntax_theme = saved_syntax_theme
    # resolved_pico_theme already set above

    # Social media metadata (for home page)
    meta_title = "Pasto - Modern Pastebin with Live Syntax Highlighting"
    meta_description = "Create and share code snippets with live syntax highlighting, SSH access, and user accounts"
    meta_url = ""
    meta_image = ""

    # Set variables for unified template
    mode = "create"
    paste = nil
    initial_content = ""
    initial_language = nil
    initial_title = nil
    paste_id = nil

    content = render "src/views/_editor_unified.ecr"
    render "src/views/layout.ecr"
  end

  # API endpoint for live syntax highlighting
  post "/highlight" do |env|
    # Rate limit check for highlight endpoint
    client_ip = Pasto.get_client_ip(env)
    allowed, result = Pasto::RateLimits.allow_highlight?(client_ip)
    add_rate_limit_headers(env, result)

    unless allowed
      env.response.status_code = 429
      retry_after = Math.max(1, (result.reset_time - Time.utc).total_seconds.ceil.to_i)
      env.response.headers["Retry-After"] = retry_after.to_s
      env.response.content_type = "application/json"
      next {"error" => "Rate limit exceeded. Retry after #{retry_after} seconds."}.to_json
    end

    content = env.params.body["content"]?.to_s
    language = env.params.body["language"]?.to_s
    theme = env.params.body["theme"]?.to_s
    line_numbers_str = env.params.body["line_numbers"]?.to_s

    content = "" if content.nil? || content.empty?
    theme = "default-dark" if theme.empty?
    line_numbers = line_numbers_str == "true"

    # Normalize line endings from \r\n and \r to \n
    content = content.gsub("\r\n", "\n").gsub("\r", "\n")

    # Handle language detection
    if language.empty? || language == "Auto" || language == ""
      language = nil
    end

    if content.empty?
      env.response.content_type = "text/html"
      next "<pre><code>Start typing to see preview...</code></pre>"
    end

    begin
      # Detect language if not provided
      detected_language = language
      if detected_language.nil? || detected_language.empty?
        detected_language = Pasto::Paste.get_best_supported_language(content)
      end

      # Use detected language for highlighting
      highlight_language = detected_language || language
      highlighted_content, _css = Pasto::Paste.highlight_content(content, highlight_language, theme, line_numbers)

      # Return JSON with both highlighted content and detected language
      env.response.content_type = "application/json"
      {
        "html"              => highlighted_content,
        "detected_language" => detected_language,
        "original_language" => language,
      }.to_json
    rescue ex
      puts "DEBUG: Highlighting failed for language '#{language}': #{ex.message}"
      # Fallback to plain text with proper escaping
      escaped_content = HTML.escape(content)
      env.response.content_type = "application/json"
      {
        "html"              => "<pre><code>#{escaped_content}</code></pre>",
        "detected_language" => language && !language.empty? ? language : nil,
        "original_language" => language,
      }.to_json
    end
  end

  # Helper structure to hold extracted paste parameters
  struct PasteParams
    property content : String
    property language : String?
    property title : String?
    property syntax_theme : String
    property expires_at : Time?
    property burn_after_reading : Bool
    property is_private : Bool
    property is_encrypted : Bool
    property encryption_iv : String?
    property password_based : Bool
    property encryption_salt : String?
    property encryption_iterations : Int32

    def initialize(@content, @language, @title, @syntax_theme, @expires_at, @burn_after_reading, @is_private, @is_encrypted, @encryption_iv, @password_based, @encryption_salt, @encryption_iterations)
    end
  end

  # Extract and validate common paste parameters from request
  private def self.extract_paste_params(env) : PasteParams
    content = env.params.body["content"]?.to_s
    language = env.params.body["language"]?.to_s
    language = nil if language.empty?

    # Get title from form
    title = env.params.body["title"]?.to_s
    title = nil if title.strip.empty?

    # Get syntax theme from form or use default
    syntax_theme = env.params.body["syntax_theme"]?.to_s
    syntax_theme = "default-dark" if syntax_theme.empty?

    # Handle expiration
    expiration_str = env.params.body["expiration"]?.to_s
    expires_at = Pasto::Paste.parse_expiration(expiration_str)

    # Handle security fields
    burn_after_reading = env.params.body["burn_after_reading"]?.to_s == "true"
    is_private = env.params.body["private"]?.to_s == "true"

    # Handle encryption fields
    is_encrypted = env.params.body["is_encrypted"]?.to_s == "true"
    encryption_iv = env.params.body["encryption_iv"]?.to_s
    encryption_iv = nil if encryption_iv.strip.empty?

    # Handle password-based encryption fields
    password_based = env.params.body["password_based"]?.to_s == "true"
    encryption_salt = env.params.body["encryption_salt"]?.to_s
    encryption_salt = nil if encryption_salt.strip.empty?

    encryption_iterations_str = env.params.body["encryption_iterations"]?.to_s
    if encryption_iterations_str.empty?
      encryption_iterations = 100000
    else
      encryption_iterations = encryption_iterations_str.to_i
      encryption_iterations = 100000 if encryption_iterations == 0
    end

    PasteParams.new(
      content, language, title, syntax_theme, expires_at,
      burn_after_reading, is_private, is_encrypted,
      encryption_iv, password_based, encryption_salt, encryption_iterations
    )
  end

  # Validate paste content and size
  private def self.validate_paste_content(content : String) : {Bool, String?}
    if content.empty?
      return {false, "Content cannot be empty"}
    end

    # Size validation
    config = Pasto.config
    if config.nil?
      return {false, "Configuration not available"}
    end

    content_bytesize = content.bytesize
    if content_bytesize > config.max_paste_size
      return {false, "Paste too large. Maximum size is #{config.max_paste_size} bytes (got #{content_bytesize} bytes)."}
    end

    {true, nil}
  end

  # Apply paste parameters to a paste object
  private def self.apply_paste_params(paste : Pasto::Paste, params : PasteParams, normalize_line_endings : Bool = false)
    # Apply content (with optional line ending normalization)
    if normalize_line_endings
      paste.content = params.content.gsub("\r\n", "\n").gsub("\r", "\n")
    else
      paste.content = params.content
    end

    paste.language = params.language
    paste.title = params.title
    paste.theme = params.syntax_theme
    if expires_at = params.expires_at
      paste.expires_at = expires_at
    end
    paste.burn_after_reading = params.burn_after_reading
    paste.private = params.is_private

    # Set encryption fields if applicable
    if params.is_encrypted
      paste.is_encrypted = true
      paste.encrypted_content = params.content
      paste.encryption_iv = params.encryption_iv
      paste.password_based = params.password_based
      paste.encryption_salt = params.encryption_salt
      paste.encryption_iterations = params.encryption_iterations
      paste.content = "" # Clear regular content for encrypted pastes
    end
  end

  # Handle paste submission
  post "/" do |env|
    # Rate limiting check
    client_ip = Pasto.get_client_ip(env)
    current_user = Pasto.get_current_user(env)
    user_id = current_user.try(&.sepia_id)

    allowed, result = Pasto::RateLimits.allow_paste?(client_ip, user_id)
    add_rate_limit_headers(env, result)

    unless allowed
      env.response.status_code = 429
      retry_after = Math.max(1, (result.reset_time - Time.utc).total_seconds.ceil.to_i)
      env.response.headers["Retry-After"] = retry_after.to_s
      next "Rate limit exceeded. Please wait #{retry_after} seconds before creating another paste."
    end

    # Extract and validate paste parameters
    params = extract_paste_params(env)

    # Validate content and size
    is_valid, error_message = validate_paste_content(params.content)
    unless is_valid
      if error_message && error_message.includes?("too large")
        env.response.status_code = 413
      else
        env.response.status_code = 400
      end
      next error_message || "Invalid content"
    end

    # Create new paste with basic parameters
    paste = Pasto::Paste.new(params.content, params.language, params.syntax_theme, user_id: user_id, title: params.title)

    # Apply all parameters to the paste
    apply_paste_params(paste, params)

    # Set burn_after_reading from either explicit checkbox or view-once expiration
    expiration_str = env.params.body["expiration"]?.to_s
    paste.burn_after_reading = params.burn_after_reading || expiration_str == "view-once"

    if paste.save
      # If user has SSH keys, add paste to their first key for consistency
      if current_user && !current_user.keys.empty?
        ssh_key = current_user.keys.first
        paste.ssh_fingerprint = ssh_key.sepia_id
        paste.save
        ssh_key.add_paste(paste)
        ssh_key.save
      end

      # Invalidate any existing cache for this paste
      Pasto::Cache.invalidate(paste.sepia_id)

      # Return JSON response with paste URL
      env.response.content_type = "application/json"
      {
        "success"      => true,
        "url"          => "#{env.request.headers["X-Forwarded-Proto"]? || "http"}://#{env.request.headers["X-Forwarded-Host"]? || env.request.headers["Host"]? || "localhost"}/#{paste.sepia_id}",
        "id"           => paste.sepia_id,
        "is_view_once" => paste.burn_after_reading?,
      }.to_json
    else
      env.response.status_code = 500
      "Failed to save paste"
    end
  end

  # Edit paste page (GET)
  get "/:id/edit" do |env|
    id = env.params.url["id"]

    paste = Pasto::Paste.from_file(id)
    if paste.nil?
      halt env, 404
    end

    # Prevent editing burn-after-reading pastes
    if paste.burn_after_reading?
      env.response.status_code = 403
      next "Burn-after-reading pastes cannot be edited"
    end

    # Validate session to get current user
    current_user = Pasto.get_current_user(env)

    # Check ownership
    unless current_user && paste.user_id == current_user.sepia_id
      env.response.status_code = 403
      next "You don't have permission to edit this paste"
    end

    # Get theme preferences with priority: user config > cookie > defaults
    saved_pico_theme = current_user.try(&.pico_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
    saved_pico_color = current_user.try(&.pico_color) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
    saved_syntax_theme = current_user.try(&.syntax_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default"

    # Resolve "auto" theme to prevent flashing - default to dark for server-side
    resolved_pico_theme = saved_pico_theme == "auto" ? "dark" : saved_pico_theme

    # Set template variables
    is_home_page = false
    page_title = "Edit Paste #{paste.sepia_id}"
    pico_theme = saved_pico_theme
    pico_color = saved_pico_color
    syntax_theme = saved_syntax_theme

    # Social media metadata (generic for edit pages)
    meta_title = "Pasto - Edit Paste"
    meta_description = "Modern pastebin with live syntax highlighting and SSH access"
    meta_url = ""
    meta_image = ""

    # Set variables for unified template
    mode = "edit"
    initial_content = paste.content
    initial_language = paste.language
    initial_title = paste.title
    paste_id = paste.sepia_id

    content = render "src/views/_editor_unified.ecr"
    render "src/views/layout.ecr"
  end

  # Edit paste submission (POST)
  post "/:id/edit" do |env|
    id = env.params.url["id"]

    paste = Pasto::Paste.from_file(id)
    if paste.nil?
      halt env, 404
    end

    # Prevent editing burn-after-reading pastes
    if paste.burn_after_reading?
      env.response.status_code = 403
      next "Burn-after-reading pastes cannot be edited"
    end

    # Validate session to get current user
    current_user = Pasto.get_current_user(env)

    # Check ownership
    unless current_user && paste.user_id == current_user.sepia_id
      env.response.status_code = 403
      next "You don't have permission to edit this paste"
    end

    # Extract and validate paste parameters
    params = extract_paste_params(env)

    # Validate content and size
    is_valid, error_message = validate_paste_content(params.content)
    unless is_valid
      if error_message && error_message.includes?("too large")
        env.response.status_code = 413
      else
        env.response.status_code = 400
      end
      next error_message || "Invalid content"
    end

    # Apply parameters to existing paste (with line ending normalization and versioning)
    apply_paste_params(paste, params, normalize_line_endings: true)
    paste.updated_at = Time.utc

    # Set burn_after_reading if view-once expiration
    expiration_str = env.params.body["expiration"]?.to_s
    if expiration_str == "view-once"
      paste.burn_after_reading = true
    end

    # Save with versioning to keep edit history
    if paste.save(force_new_generation: true)
      # Invalidate cache
      Pasto::Cache.invalidate(paste.sepia_id)

      # Redirect to the paste view
      env.redirect "/#{paste.sepia_id}"
    else
      env.response.status_code = 500
      "Failed to save paste"
    end
  end

  # Fork paste (create a copy owned by current user)
  post "/:id/fork" do |env|
    id = env.params.url["id"]

    # Must be logged in to fork
    current_user = Pasto.get_current_user(env)
    unless current_user
      env.response.status_code = 401
      next "You must be logged in to fork a paste"
    end

    # Rate limit forks the same as paste creation
    client_ip = Pasto.get_client_ip(env)
    allowed, result = Pasto::RateLimits.allow_paste?(client_ip, current_user.sepia_id)
    add_rate_limit_headers(env, result)

    unless allowed
      env.response.status_code = 429
      retry_after = Math.max(1, (result.reset_time - Time.utc).total_seconds.ceil.to_i)
      env.response.headers["Retry-After"] = retry_after.to_s
      next "Rate limit exceeded. Please wait #{retry_after} seconds."
    end

    original_paste = Pasto::Paste.from_file(id)
    if original_paste.nil?
      halt env, 404
    end

    # Create new paste with same content
    forked_paste = Pasto::Paste.new(
      original_paste.content,
      original_paste.language,
      original_paste.theme,
      user_id: current_user.sepia_id,
      title: original_paste.title,
      filename: original_paste.filename
    )

    if forked_paste.save
      # If user has SSH keys, associate with first key
      if !current_user.keys.empty?
        ssh_key = current_user.keys.first
        forked_paste.ssh_fingerprint = ssh_key.sepia_id
        forked_paste.save
        ssh_key.add_paste(forked_paste)
        ssh_key.save
      end

      env.redirect "/#{forked_paste.sepia_id}"
    else
      env.response.status_code = 500
      "Failed to fork paste"
    end
  end

  # Delete paste (owner only)
  post "/:id/delete" do |env|
    id = env.params.url["id"]

    # Must be logged in first
    current_user = Pasto.get_current_user(env)
    unless current_user
      env.response.content_type = "application/json"
      env.response.status_code = 401
      next {"success" => false, "error" => "You must be logged in to delete pastes"}.to_json
    end

    # Try to find the paste safely - if it doesn't exist, return success
    paste = Pasto::Paste.from_file(id)
    if paste.nil?
      # Paste doesn't exist, return success for idempotent behavior
      env.response.content_type = "application/json"
      next {"success" => true, "message" => "Paste already deleted"}.to_json
    end

    # Check ownership
    unless paste.user_id == current_user.sepia_id
      env.response.content_type = "application/json"
      env.response.status_code = 403
      next {"success" => false, "error" => "You don't have permission to delete this paste"}.to_json
    end

    # Remove paste from user's SSH key pastes array
    if !current_user.keys.empty?
      current_user.keys.each do |ssh_key|
        ssh_key.pastes.reject! { |paste_item| paste_item.sepia_id == paste.sepia_id || paste_item.base_id == paste.base_id }
        ssh_key.save
      end
    end

    # Delete all versions of the paste
    base_id = paste.base_id
    versions = Pasto::Paste.versions(base_id)
    versions.each do |version|
      Pasto::Cache.invalidate(version.sepia_id)
      Sepia::Storage.delete(version)
    end

    # Also delete the base paste if it exists separately
    begin
      if base_paste = Pasto::Paste.from_file(base_id)
        Pasto::Cache.invalidate(base_id)
        Sepia::Storage.delete(base_paste)
      end
    rescue
      # Base paste doesn't exist, which is fine
    end

    # Return JSON response
    env.response.content_type = "application/json"
    {"success" => true, "message" => "Paste deleted successfully"}.to_json
  end

  # View paste history (list of versions)
  get "/:id/history" do |env|
    id = env.params.url["id"]

    # Get the base ID (strip any generation suffix)
    base_id = if id.includes?(".")
                parts = id.split(".")
                if parts.last.matches?(/^\d+$/)
                  parts[0..-2].join(".")
                else
                  id
                end
              else
                id
              end

    # Get all versions of the paste
    versions = Pasto::Paste.versions(base_id)

    if versions.empty?
      halt env, 404
    end

    # Get current user for ownership check
    current_user = Pasto.get_current_user(env)

    # Check if user can see history (owner only for now)
    latest = versions.last
    unless current_user && latest.user_id == current_user.sepia_id
      env.response.status_code = 403
      next "Only the paste owner can view history"
    end

    # Get theme preferences with priority: user config > cookie > defaults
    saved_pico_theme = current_user.try(&.pico_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
    saved_pico_color = current_user.try(&.pico_color) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
    saved_syntax_theme = current_user.try(&.syntax_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default"

    # Resolve "auto" theme to prevent flashing - default to dark for server-side
    resolved_pico_theme = saved_pico_theme == "auto" ? "dark" : saved_pico_theme

    # Sort by generation (newest first)
    versions = versions.reverse

    # Set template variables
    is_home_page = false
    page_title = "History: #{latest.display_title}"
    pico_theme = saved_pico_theme
    pico_color = saved_pico_color
    syntax_theme = saved_syntax_theme

    # Social media metadata (generic for history pages)
    meta_title = "Pasto - Paste History"
    meta_description = "Modern pastebin with live syntax highlighting and SSH access"
    meta_url = ""
    meta_image = ""

    content = render "src/views/history.ecr"
    render "src/views/layout.ecr"
  end

  # View a specific version of a paste
  get "/:id/version/:gen" do |env|
    id = env.params.url["id"]
    gen = env.params.url["gen"].to_i

    # Construct the versioned ID
    versioned_id = "#{id}.#{gen}"

    begin
      paste = Pasto::Paste.load(versioned_id)
    rescue
      env.response.status_code = 404
      next "Version not found"
    end

    # Get current user
    current_user = Pasto.get_current_user(env)

    # Get theme preferences with priority: user config > cookie > defaults
    saved_pico_theme = current_user.try(&.pico_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
    saved_pico_color = current_user.try(&.pico_color) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
    saved_syntax_theme = current_user.try(&.syntax_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default"

    # Resolve "auto" theme to prevent flashing - default to dark for server-side
    resolved_pico_theme = saved_pico_theme == "auto" ? "dark" : saved_pico_theme

    # Generate highlighted content
    highlighted_content = paste.highlight(nil)[0]

    # Version count for the history button
    version_count = 0
    if current_user && paste.user_id == current_user.sepia_id
      version_count = Pasto::Paste.versions(id).size
    end

    # Set template variables
    is_home_page = false
    page_title = paste.display_title
    is_version_view = true
    base_paste_id = id
    pico_theme = saved_pico_theme
    pico_color = saved_pico_color
    syntax_theme = saved_syntax_theme

    # Generate social media metadata for version view
    meta_title = "#{paste.display_title} (v#{paste.generation})"
    meta_description = generate_meta_description(paste.content)
    host = env.request.headers["Host"]? || "localhost:3000"
    meta_url = "http://#{host}#{env.request.path}"
    meta_image = "http://#{host}/preview/#{paste.sepia_id}.png"

    content = render "src/views/show.ecr"
    render "src/views/layout.ecr"
  end

  # ...existing code...

  # Serve static files from public directory
  public_dir = "#{Dir.current}/public"
  Kemal.config.public_folder = public_dir

  # Serve syntax highlighting CSS

  # Favicon handler - returns baked PNG favicon

  # Serve cached files directly if they exist

  # 404 page route
  get "/404" do |env|
    current_user = Pasto.get_current_user(env)
    saved_pico_theme = current_user.try(&.pico_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
    saved_pico_color = current_user.try(&.pico_color) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
    saved_syntax_theme = current_user.try(&.syntax_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default"
    page_title = "404 - Not Found"
    is_home_page = false
    pico_theme = saved_pico_theme
    pico_color = saved_pico_color
    syntax_theme = saved_syntax_theme
    resolved_pico_theme = saved_pico_theme == "auto" ? "dark" : saved_pico_theme

    # Social media metadata
    meta_title = "404 - Not Found - Pasto"
    meta_description = "The requested paste could not be found on Pasto"
    meta_url = ""
    meta_image = ""

    # Set 404 status code
    env.response.status_code = 404

    reason = "not_found"

    content = render "src/views/404.ecr"
    render "src/views/layout.ecr"
  end

  # Error handling for other 404 cases
  error 404 do |env|
    current_user = Pasto.get_current_user(env)
    saved_pico_theme = current_user.try(&.pico_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
    saved_pico_color = current_user.try(&.pico_color) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
    saved_syntax_theme = current_user.try(&.syntax_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default"
    page_title = "404 - Not Found"
    is_home_page = false
    pico_theme = saved_pico_theme
    pico_color = saved_pico_color
    syntax_theme = saved_syntax_theme
    resolved_pico_theme = saved_pico_theme == "auto" ? "dark" : saved_pico_theme

    # Social media metadata
    meta_title = "404 - Not Found - Pasto"
    meta_description = "The requested paste could not be found on Pasto"
    meta_url = ""
    meta_image = ""

    # Set 404 status code
    env.response.status_code = 404

    reason = "not_found"

    content = render "src/views/404.ecr"
    render "src/views/layout.ecr"
  end

  # Preview image route for social media cards (must come before catch-all routes)
  get "/preview/:id" do |env|
    # Assume the id parameter includes the .png extension
    id_with_ext = env.params.url["id"]
    id = id_with_ext.gsub(/\.png$/, "")

    if id.nil? || id.empty?
      env.response.status_code = 400
      next "Invalid preview request"
    end

    client_ip = Pasto.get_client_ip(env)

    # Rate limiting for preview generation (use existing highlight limiter)
    allowed, _ = Pasto::RateLimits.allow_highlight?(client_ip)
    unless allowed
      env.response.status_code = 429
      next "Rate limit exceeded for preview generation"
    end

    paste = Pasto::Paste.from_file(id)
    if paste.nil?
      # Generate and serve 404 placeholder
      placeholder_path = generate_placeholder_file("Paste not found")
      env.response.status_code = 404
      env.response.headers["Cache-Control"] = "public, max-age=300" # 5 minutes for errors
      next send_file env, placeholder_path
    end

    # Handle burn after reading functionality for previews
    # Note: We don't increment view count for previews to avoid accidental burning
    if paste.burn_after_reading? && paste.should_burn_after_reading?
      placeholder_path = generate_placeholder_file("Paste not found")
      env.response.status_code = 404
      env.response.headers["Cache-Control"] = "public, max-age=300" # 5 minutes for errors
      next send_file env, placeholder_path
    end

    cache_path = PreviewGenerator.get_cache_path(id)

    # Generate cached image if it doesn't exist
    unless File.exists?(cache_path) && File.info(cache_path).modification_time > paste.updated_at
      begin
        PreviewGenerator.save_preview_image(paste, cache_path)
      rescue ex
        # Generate and serve error placeholder
        placeholder_path = generate_placeholder_file("Error generating preview")
        env.response.headers["Cache-Control"] = "public, max-age=300" # 5 minutes for errors
        next send_file env, placeholder_path
      end
    end

    # Serve the cached image using Kemal's optimized send_file helper
    env.response.headers["Cache-Control"] = "public, max-age=3600" # 1 hour
    send_file env, cache_path
  end

  get "/:id" do |env|
    id = env.params.url["id"]
    request_path = env.request.path
    language_override = nil

    # Check if the path contains an extension (a dot followed by more characters)
    if request_path.includes?(".") && request_path.count('.') > 0
      # Split by the last dot to separate ID from extension
      parts = request_path.split(".")
      if parts.size >= 2
        paste_id = parts[0..-2].join(".")
        ext = parts[-1]

        # Use the paste_id as the id for the rest of the route
        id = paste_id

        begin
          paste = Pasto::Paste.from_file(paste_id)
          if paste.nil?
            halt env, 404
          end
        rescue
          halt env, 404
        end

        # Map extension to language
        language_override = paste.language_for_extension(ext)
      end
    end

    # Load the paste (either with original id or modified id from extension handling)
    begin
      paste = Pasto::Paste.from_file(id)
      if paste.nil?
        halt env, 404
      end
    rescue
      halt env, 404
    end

    # Validate session to get current user (needed for private paste check)
    current_user = Pasto.get_current_user(env)

    # Check if paste is private and user is not the owner
    if paste.private? && paste.user_id != (current_user.try(&.sepia_id))
      env.response.status_code = 403
      next "This paste is private and can only be accessed by the owner"
    end

    # Note: For burn-after-reading pastes, we'll increment the view count AFTER showing the content
    # This ensures the user can see the paste once before it gets deleted

    # Get theme preferences with priority: user config > cookie > defaults
    saved_pico_theme = current_user.try(&.pico_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
    saved_pico_color = current_user.try(&.pico_color) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
    saved_syntax_theme = current_user.try(&.syntax_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default"

    # Resolve "auto" theme to prevent flashing - default to dark for server-side
    resolved_pico_theme = saved_pico_theme == "auto" ? "dark" : saved_pico_theme

    # Get language override from URL parameter if present
    url_lang_override = env.params.query["lang"]?
    if url_lang_override && !url_lang_override.empty?
      language_override = url_lang_override
    end

    # Generate highlighted content
    highlighted_content = paste.highlight(language_override)[0]

    # Get version count for history button (only if user owns the paste)
    version_count = 0
    if current_user && paste.user_id == current_user.sepia_id
      version_count = Pasto::Paste.versions(paste.base_id).size
    end

    # Set version view flags (not a version view in main route)
    is_version_view = false
    base_paste_id = paste.base_id

    # Set template variables (ECR template will have access to these)
    pico_theme = saved_pico_theme
    pico_color = saved_pico_color
    syntax_theme = saved_syntax_theme
    is_home_page = false
    page_title = "Paste #{paste.sepia_id}"

    # Generate social media metadata with preview images
    meta_title = paste.display_title.size > 60 ? paste.display_title[0..57] + "..." : paste.display_title
    meta_description = generate_meta_description(paste.content)
    host = env.request.headers["Host"]? || "localhost:3000"
    meta_url = "http://#{host}#{env.request.path}"
    meta_image = "http://#{host}/preview/#{paste.sepia_id}.png"

    # Mark paste for burning after response if it's burn-after-reading
    if paste.burn_after_reading?
      env.response.headers["X-Burn-After-Reading"] = paste.sepia_id
    end

    content = render "src/views/show.ecr"
    render "src/views/layout.ecr"
  end

  # Serve static files from public directory
  public_dir = "#{Dir.current}/public"
  Kemal.config.public_folder = public_dir

  # Serve syntax highlighting CSS for specific theme family and variant
  get "/syntax/:family/:variant" do |env|
    family = env.params.url["family"].gsub(/-dark$/, "").gsub(/-light$/, "")
    variant = env.params.url["variant"]
    theme_name = "#{family}/#{variant}"

    begin
      # Use Tartrazine theme CSS for the specified theme and variant
      formatter = Tartrazine::Html.new(theme: Tartrazine.theme(family, variant))
      css = formatter.style_defs

      env.response.content_type = "text/css"
      css
    rescue ex
      env.response.status_code = 404
      env.response.content_type = "text/plain"
      "Theme not found: #{theme_name}"
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

  # Raw paste endpoint
  get "/:id/raw" do |env|
    id = env.params.url["id"]

    # Load the paste
    paste = Pasto::Paste.from_file(id)
    if paste.nil?
      halt env, 404
    end

    # Note: For burn-after-reading pastes in raw endpoint, we'll increment after sending content

    # Validate session to get current user (needed for private paste check)
    current_user = Pasto.get_current_user(env)

    # Check if paste is private and user is not the owner
    if paste.private? && paste.user_id != (current_user.try(&.sepia_id))
      env.response.status_code = 403
      next "This paste is private and can only be accessed by the owner"
    end

    # Get appropriate MIME type and filename
    extension = Pasto::MimeTypes.get_file_extension(paste.language)
    mime_type = MIME.from_extension(".#{extension}")
    filename = Pasto::MimeTypes.generate_filename(paste)

    # Set content type based on language
    env.response.content_type = mime_type

    # Set content disposition to trigger download with proper filename
    env.response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""

    # Mark paste for burning after response if it's burn-after-reading
    if paste.burn_after_reading?
      env.response.headers["X-Burn-After-Reading"] = paste.sepia_id
    end

    # For encrypted pastes, return the encrypted content
    # For regular pastes, return the raw content
    content = if paste.is_encrypted? && paste.responds_to?(:encrypted_content) && paste.encrypted_content
                paste.encrypted_content
              else
                paste.content
              end

    content
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
      puts "API: Failed to create paste: #{ex.message}"
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
      "language"           => paste.language,
      "created_at"         => paste.created_at.to_rfc3339,
      "private"            => paste.private?,
      "encrypted"          => paste.is_encrypted?,
      "burn_after_reading" => paste.burn_after_reading?,
      "size"               => paste.content.bytesize,
      "is_owner"           => paste.user_id == api_user.sepia_id,
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
      puts "API: Failed to delete paste: #{ex.message}"
      env.response.status_code = 500
      {
        "error"   => "Internal Server Error",
        "message" => "Failed to delete paste",
      }.to_json
    end
  end
end
