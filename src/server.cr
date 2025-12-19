require "openssl"
require "./api"
require "./assets"
require "pasto-cache"
require "./filters"
require "./health"
require "./help"
require "./mimetypes"
require "./models/*"
require "./paste"
require "./logging"
require "./preview_generator"
require "qr-code"
require "./profile"
require "./ratelimit"
require "./rate_limit_helper"
require "./ssh_utils"
require "./theme_helper"
require "./user_session"
require "ecr"
require "file_utils"
require "http"
require "kemal-session"
require "kemal"
require "qr-code/export/png"
require "tartrazine"

module Pasto
  # Extracts UserSession from Kemal session and fetches User from Sepia storage
  # Returns nil for unauthenticated users or invalid sessions
  def self.get_current_user(env) : User?
    if user_session = env.session.object?("user").as(Pasto::UserSession?)
      User.find(user_session.user_id)
    else
      nil
    end
  end

  # Unified access control result
  struct AccessResult
    property? allowed : Bool
    property paste : Pasto::Paste?
    property status_code : Int32

    def initialize(@allowed : Bool, @paste : Pasto::Paste? = nil, @status_code : Int32 = 200)
    end

    def success? : Bool
      @allowed && @paste != nil
    end
  end

  # Validates paste access control and returns structured access result
  #
  # This function consolidates paste access validation logic including existence checks,
  # user authentication, and permission verification. Used by both middleware filters
  # and route handlers for consistent access control.
  #
  # Arguments:
  #   env - HTTP request environment containing session and routing information
  #   require_owner - If true, only allows access to paste owners (used for edit/delete operations)
  #
  # Returns:
  #   AccessResult with success status, paste object (if accessible), and appropriate HTTP status code
  #   - 400 for missing or empty paste IDs in URL parameters
  #   - 403 for permission/ownership violations
  #   - 404 for non-existent pastes
  #   - 200 for successful access
  def self.validate_paste_access(env, require_owner : Bool = false) : AccessResult
    id = extract_paste_id(env)

    return AccessResult.new(false, status_code: 400) if id.nil? || id.empty?

    # Load the paste
    paste = Pasto::Paste.from_file(id)
    return AccessResult.new(false, status_code: 404) if paste.nil?

    # Only get current user if we need to check ownership or private access
    if require_owner || paste.private?
      current_user = get_current_user(env)
      current_user_id = current_user.try(&.sepia_id)

      # Check ownership requirement
      if current_user_id == paste.user_id
        return AccessResult.new(true, paste: paste)
      else
        # Access denied - ownership required or paste is private and user is not owner
        return AccessResult.new(false, status_code: 403)
      end
    end

    # Access granted - public paste and no ownership requirement
    AccessResult.new(true, paste: paste)
  rescue
    AccessResult.new(false, status_code: 404)
  end

  # Extract paste ID from various URL patterns
  private def self.extract_paste_id(env) : String?
    # Try the simple case first
    id = env.params.url["id"]?
    return nil unless id

    # Handle special cases only when needed
    path = env.request.path

    # Remove .png from preview URLs
    if path.includes?("/preview/")
      return id.gsub(/\.png$/, "")
    end

    # Handle file extensions in main paste view (/:id.py)
    if path.count('.') > 1 && !path.includes?("/api/")
      return id.split(".")[0..-2].join(".")
    end

    id
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
      access_result = Pasto.validate_paste_access(env)
      unless access_result.success?
        halt env, access_result.status_code
      end
    else
      # edit and delete require ownership
      access_result = Pasto.validate_paste_access(env, require_owner: true)
      unless access_result.success?
        halt env, access_result.status_code
      end
    end
  end

  # Create backup for current user
  post "/profile/backups/create" do |env|
    current_user = Pasto.get_current_user(env)

    unless current_user
      env.response.status_code = 401
      if env.request.headers["X-Requested-With"]? == "XMLHttpRequest"
        env.response.content_type = "application/json"
        {"status" => "error", "message" => "Unauthorized"}.to_json
      else
        env.redirect "/profile?error=unauthorized"
      end
      next
    end

    # Check backup rate limiting
    allowed, rate_limit_result = RateLimits.allow_backup?(current_user.sepia_id)
    unless allowed
      Pasto::Logging.warn("Backup rate limit exceeded for user #{current_user.sepia_id}")
      env.response.status_code = 429
      if env.request.headers["X-Requested-With"]? == "XMLHttpRequest"
        env.response.content_type = "application/json"
        {"status" => "error", "message" => "Rate limit exceeded. You can create one backup per day."}.to_json
      else
        env.redirect "/profile?error=rate_limit"
      end
      next
    end

    # Get config for storage directory
    config = Pasto.config

    # Spawn backup process asynchronously
    spawn do
      backup_binary = File.join(Dir.current, "bin", "pasto-backup")
      args = [
        "--user-id=#{current_user.sepia_id}",
        "--storage-dir=#{config.storage_dir}",
        "--log-level=#{config.log_level || "info"}",
      ]

      result = Process.run(
        backup_binary,
        args,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe
      )

      unless result.success?
        Pasto::Logging.error("Backup creation failed for user #{current_user.sepia_id}: exit code #{result.exit_code}")
      end
    end

    # Return immediate response
    if env.request.headers["X-Requested-With"]? == "XMLHttpRequest"
      env.response.content_type = "application/json"
      {"status" => "success", "message" => "Backup creation started. This may take a few minutes to complete."}.to_json
    else
      env.redirect "/profile?backup=started"
    end
  end

  # Get backup status for current user
  get "/profile/backups" do |env|
    current_user = Pasto.get_current_user(env)

    unless current_user
      env.response.status_code = 401
      next {"status" => "error", "message" => "Unauthorized"}.to_json
    end

    backup_status = Pasto::BackupManager.get_backup_status(current_user.sepia_id)

    case backup_status[:status]
    when "available"
      backup = backup_status[:backup]
      if backup
        env.response.content_type = "application/json"
        {
          "status"       => "available",
          "created_at"   => backup["created_at"].as_s,
          "file_size"    => backup["file_size"].as_i64,
          "download_url" => "/profile/backups/download",
        }.to_json
      else
        {"status" => "none", "message" => "No backup available"}.to_json
      end
    when "in_progress"
      {"status" => "in_progress", "message" => "Backup creation in progress"}.to_json
    when "none"
      {"status" => "none", "message" => "No backup available"}.to_json
    when "corrupted"
      {"status" => "corrupted", "message" => "Backup file is corrupted: #{backup_status[:error]}"}.to_json
    when "error"
      env.response.status_code = 500
      {"status" => "error", "message" => "Error checking backup status: #{backup_status[:error]}"}.to_json
    else
      env.response.status_code = 500
      {"status" => "error", "message" => "Unknown backup status"}.to_json
    end
  end

  # Download backup for current user
  get "/profile/backups/download" do |env|
    current_user = Pasto.get_current_user(env)

    Pasto::Logging.info("Download request - current_user: #{current_user ? current_user.sepia_id : "nil"}")

    unless current_user
      env.response.status_code = 401
      next "Unauthorized"
    end

    # Get backup status
    backup_status = Pasto::BackupManager.get_backup_status(current_user.sepia_id)

    if backup_status[:status] != "available" || !backup_status[:backup]
      env.response.status_code = 404
      next "No backup available for download"
    end

    backup = backup_status[:backup]

    Pasto::Logging.info("Download validation - backup_status: #{backup_status[:status]}, backup: #{backup ? "exists" : "nil"}")

    # Verify backup accessibility
    unless backup && backup["user_id"].as_s == current_user.sepia_id
      env.response.status_code = 403
      Pasto::Logging.warn("Unauthorized backup download attempt by user #{current_user.sepia_id} - backup_user_id: #{backup ? backup["user_id"].as_s : "nil"}")
      next "Access denied"
    end

    # Get backup file path
    backup_file_path = backup["file_path"].as_s

    # Verify backup file exists
    unless File.exists?(backup_file_path)
      env.response.status_code = 404
      Pasto::Logging.warn("Backup file not found for user #{current_user.sepia_id}: #{backup_file_path}")
      next "Backup file not found"
    end

    # Serve backup file
    begin
      env.response.content_type = "application/gzip"
      env.response.headers["Content-Disposition"] = "attachment; filename=\"pasto_backup_#{current_user.sepia_id}.sepia.tar.gz\""
      env.response.headers["Content-Length"] = File.size(backup_file_path).to_s

      Pasto::Logging.info("User #{current_user.sepia_id} downloaded backup: #{backup_file_path}")

      # Stream file content
      File.open(backup_file_path, "rb") do |file|
        IO.copy(file, env.response)
      end
    rescue ex
      env.response.status_code = 500
      Pasto::Logging.error("Error serving backup file: #{ex.message}")
      "Error downloading backup file"
    end
  end

  # Logout route - clear session
  post "/logout" do |env|
    # Clear the session using kemal-session
    env.session.destroy

    Pasto::Logging.info("User logged out")

    env.redirect "/?logout=success"
  end

  # SSH Auth token route - validate token and create session
  get "/auth/:token" do |env|
    token_id = env.params.url["token"]
    client_ip = Pasto.get_client_ip(env)

    # Rate limit login attempts
    allowed, rate_limit_response = Pasto::RateLimitHelper.check_and_handle_rate_limit(env, :login)
    unless allowed
      next rate_limit_response
    end

    token = Pasto::AuthToken.find(token_id)

    if token.nil? || token.expired?
      # Delete expired token if it exists
      token.try(&.delete)

      env.response.status_code = 404
      current_user = Pasto.get_current_user(env)
      theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)

      # Set individual variables
      page_title = "Invalid Token"
      is_home_page = false
      meta_title = "Pasto - Authentication Error"
      meta_description = "Modern pastebin with live syntax highlighting and SSH access"
      meta_url = "/auth/error"
      meta_image = "/favicon.png"

      content = render "src/views/auth_error.ecr"
      render "src/views/layout.ecr"
      next
    end

    # Load or create SSHKey
    ssh_key = Pasto::SSHKey.find_or_create(token.fingerprint)

    # Check if key already has an owner
    user = if owner_id = ssh_key.owner_id
             Pasto::User.find(owner_id)
           else
             nil
           end

    # If no user exists, create one and link the key
    if user.nil?
      user = Pasto::User.new
      user.save             # Save first to get sepia_id
      user.add_key(ssh_key) # This sets owner_id and adds to keys array
      user.save             # Save again with the key added
      Pasto::Logging.info("Created new user #{user.sepia_id} for SSH key #{token.fingerprint}")
    else
      # Make sure the key is in the user's keys array (in case of data inconsistency)
      unless user.keys.any? { |k| k.sepia_id == ssh_key.sepia_id }
        user.add_key(ssh_key)
        user.save
        Pasto::Logging.info("Added SSH key #{token.fingerprint} to existing user #{user.sepia_id}")
      end
      Pasto::Logging.info("Existing user #{user.sepia_id} logging in via SSH key #{token.fingerprint}")
    end

    # Create session
    user_session = Pasto::UserSession.new(user.sepia_id, nil, client_ip)
    env.session.object("user", user_session)

    # Delete the token (one-time use)
    token.delete

    Pasto::Logging.info("SSH auth successful for user #{user.sepia_id} from #{client_ip}")

    # Redirect to home with success message
    env.redirect "/?ssh_login=success"
  end

  # Main page - paste creation form
  get "/" do |env|
    config = Pasto.config
    # Validate session to get current user
    current_user = Pasto.get_current_user(env)

    # Get all theme-related template variables
    theme_vars = Pasto::ThemeHelper.setup_vars(current_user, config)

    # Set template variables (ECR template will have access to these)
    is_home_page = true
    page_title = "Pasto"

    # Social media metadata (for home page)
    meta_title = "Pasto - Modern Pastebin with Live Syntax Highlighting"
    meta_description = "Create and share code snippets with live syntax highlighting, SSH access, and user accounts"
    meta_url = "/"
    meta_image = "/assets/favicon.png"

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
    allowed, rate_limit_response = Pasto::RateLimitHelper.check_and_handle_rate_limit(env, :highlight)
    unless allowed
      next rate_limit_response
    end

    # Normalize line endings from \r\n and \r to \n
    content = env.params.body["content"]?.to_s.gsub("\r\n", "\n").gsub("\r", "\n")
    theme = env.params.body["theme"]?.to_s.empty? ? config.theme : env.params.body["theme"]?.to_s
    line_numbers = env.params.body["line_numbers"]?.to_s == "true"

    # Handle language detection
    language = env.params.body["language"]?.to_s
    if language.empty? || language == "Auto"
      language = Pasto::Paste.get_best_supported_language(content)
    end

    # Use detected language for highlighting
    highlighted_content, _css = Pasto::Paste.highlight_content(content, language, "monokai", line_numbers)

    # Create response
    response_json = {
      "html"     => highlighted_content,
      "language" => language,
    }.to_json

    # Return JSON with both highlighted content and detected language
    env.response.content_type = "application/json"
    response_json
  rescue ex
    Pasto::Logging.error("Highlighting failed for language '#{language}': #{ex.message}")
    # Fallback to plain text with proper escaping
    escaped_content = HTML.escape(content.to_s)
    env.response.content_type = "application/json"
    {
      "html"     => "<pre><code>#{escaped_content}</code></pre>",
      "language" => language,
    }.to_json
  end

  # Helper structure to hold extracted paste parameters
  struct PasteParams
    property content : String
    property language : String?
    property title : String?
    property syntax_theme : String
    property expires_at : Time?
    property? burn_after_reading : Bool
    property? is_private : Bool
    property? is_encrypted : Bool
    property encryption_iv : String?
    property? password_based : Bool
    property encryption_salt : String?
    property encryption_iterations : Int32
    property user_id : String?

    # Initialize from HTTP request environment
    def initialize(env : HTTP::Server::Context)
      @content = env.params.body["content"]?.to_s
      language = env.params.body["language"]?.to_s
      @language = language.empty? ? nil : language

      # Get title from form
      @title = env.params.body["title"]?.to_s.strip.empty? ? nil : env.params.body["title"]?.to_s

      # Get syntax theme from form or use default
      @syntax_theme = env.params.body["syntax_theme"]?.to_s.empty? ? Pasto.config.theme : env.params.body["syntax_theme"]?.to_s

      # Handle expiration
      expiration_str = env.params.body["expiration"]?.to_s
      @expires_at = Pasto::Paste.parse_expiration(expiration_str)

      # Extract current user ID
      current_user = Pasto.get_current_user(env)
      @user_id = current_user.try(&.sepia_id)

      # Handle security fields
      @burn_after_reading = env.params.body["burn_after_reading"]?.to_s == "true"
      @is_private = env.params.body["private"]?.to_s == "true"

      # Handle encryption fields
      @is_encrypted = env.params.body["is_encrypted"]?.to_s == "true"
      @encryption_iv = env.params.body["encryption_iv"]?.to_s.strip.empty? ? nil : env.params.body["encryption_iv"]?.to_s

      # Handle password-based encryption fields
      @password_based = env.params.body["password_based"]?.to_s == "true"
      @encryption_salt = env.params.body["encryption_salt"]?.to_s.strip.empty? ? nil : env.params.body["encryption_salt"]?.to_s

      encryption_iterations_str = env.params.body["encryption_iterations"]?.to_s
      if encryption_iterations_str.empty?
        @encryption_iterations = 100000
      else
        @encryption_iterations = encryption_iterations_str.to_i
        @encryption_iterations = 100000 if @encryption_iterations == 0
      end
    end
  end

  # Validate paste content and size
  private def self.validate_paste_content(content : String) : {Bool, String?}
    if content.empty?
      return {false, "Content cannot be empty"}
    end

    # Size validation
    if content.bytesize > Pasto.config.max_paste_size
      return {false, "Paste too large. Maximum size is #{Pasto.config.max_paste_size} bytes (got #{content.bytesize} bytes)."}
    end

    {true, nil}
  end

  # Apply paste parameters to a paste object
  private def self.apply_paste_params(paste : Pasto::Paste, params : PasteParams)
    # Apply content with line ending normalization
    paste.content = params.content.gsub("\r\n", "\n").gsub("\r", "\n")

    paste.language = params.language
    paste.title = params.title
    paste.theme = params.syntax_theme
    paste.user_id = params.user_id
    if expires_at = params.expires_at
      paste.expires_at = expires_at
    end
    paste.burn_after_reading = params.burn_after_reading?
    paste.private = params.is_private?

    # Set encryption fields if applicable
    if params.is_encrypted?
      paste.is_encrypted = true
      paste.encrypted_content = params.content
      paste.encryption_iv = params.encryption_iv
      paste.password_based = params.password_based?
      paste.encryption_salt = params.encryption_salt
      paste.encryption_iterations = params.encryption_iterations
      paste.content = "" # Clear regular content for encrypted pastes
    end
  end

  # Handle paste submission
  post "/" do |env|
    # Rate limiting check
    current_user = Pasto.get_current_user(env)
    user_id = current_user.try(&.sepia_id)

    allowed, rate_limit_response = Pasto::RateLimitHelper.check_and_handle_rate_limit(env, :paste, user_id)
    unless allowed
      next rate_limit_response
    end

    # Extract and validate paste parameters
    params = PasteParams.new(env)

    # Prevent anonymous users from creating private pastes
    if params.is_private? && current_user.nil?
      env.response.status_code = 403
      next "You must be logged in to create private pastes"
    end

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

    # Create new paste that will be populated by apply_paste_params
    paste = Pasto::Paste.new

    # Apply all parameters to the paste
    apply_paste_params(paste, params)

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
    # Use the existing access validation function
    access = Pasto.validate_paste_access(env, require_owner: true)
    unless access.allowed?
      halt env, access.status_code
    end

    if access.paste
      paste = access.paste.as(Pasto::Paste)
    else
      halt env, 404
    end

    # Prevent editing burn-after-reading pastes
    if paste.burn_after_reading?
      env.response.status_code = 403
      next "Burn-after-reading pastes cannot be edited"
    end

    current_user = Pasto.get_current_user(env)

    # Get all theme-related template variables
    theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)

    # Set template variables
    is_home_page = false
    page_title = "Edit Paste #{paste.sepia_id}"

    # Social media metadata for edit page
    meta_title = "Pasto - Edit Paste #{paste.sepia_id}"
    meta_description = "Edit paste with live syntax highlighting and SSH access"
    meta_url = "/#{paste.sepia_id}"
    meta_image = "/assets/favicon.png"

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
    # Validate access
    access = Pasto.validate_paste_access(env, require_owner: true)

    unless access.allowed?
      halt env, access.status_code
    end

    if access.paste
      paste = access.paste.as(Pasto::Paste)
    else
      halt env, 404
    end

    # Extract and validate paste parameters
    params = PasteParams.new(env)

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
    apply_paste_params(paste, params)
    paste.updated_at = Time.utc

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
    allowed, rate_limit_response = Pasto::RateLimitHelper.check_and_handle_rate_limit(env, :paste, current_user.sepia_id)
    unless allowed
      next rate_limit_response
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
    # Validate access
    access = Pasto.validate_paste_access(env, require_owner: true)

    unless access.allowed?
      env.response.content_type = "application/json"
      env.response.status_code = access.status_code
      next {"success" => false, "error" => "Access denied"}.to_json
    end

    if access.paste
      paste = access.paste.as(Pasto::Paste)
    else
      # Paste doesn't exist, return success for idempotent behavior
      env.response.content_type = "application/json"
      next {"success" => true, "message" => "Paste already deleted"}.to_json
    end

    # Remove paste from user's SSH key pastes array
    if user = Pasto.get_current_user(env)
      user.keys.each do |ssh_key|
        ssh_key.pastes.reject! { |paste_item| paste_item.sepia_id == paste.sepia_id || paste_item.base_id == paste.base_id }
        ssh_key.save
      end
    end

    # Delete the paste completely (handles all versions automatically)
    paste.delete_completely!

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

    # Validate access using centralized function
    access = Pasto.validate_paste_access(env)

    unless access.allowed?
      halt env, access.status_code
    end

    if access.paste
      paste = access.paste.as(Pasto::Paste)
    else
      halt env, 404
    end

    # Get all versions of the paste
    versions = Pasto::Paste.versions(paste.base_id)

    if versions.empty?
      halt env, 404
    end

    # Get current user for theme setup
    current_user = Pasto.get_current_user(env)

    # Get all theme-related template variables
    theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)

    # Sort by generation (newest first)
    versions = versions.reverse

    # Set template variables
    is_home_page = false
    page_title = "History: #{paste.display_title}"

    # Social media metadata (generic for history pages)
    meta_title = "Pasto - Paste History"
    meta_description = "Modern pastebin with live syntax highlighting and SSH access"
    meta_url = "/#{paste.sepia_id}/history"
    meta_image = "/favicon.png"

    content = render "src/views/history.ecr"
    render "src/views/layout.ecr"
  end

  # View a specific version of a paste
  get "/:id/version/:gen" do |env|
    id = env.params.url["id"]
    gen = env.params.url["gen"].to_i

    # Construct the versioned ID
    versioned_id = "#{id}.#{gen}"

    # Validate access using centralized function
    access = Pasto.validate_paste_access(env)

    unless access.allowed?
      halt env, access.status_code
    end

    if access.paste
      paste = access.paste.as(Pasto::Paste)
    else
      halt env, 404
    end

    # Load the specific version
    begin
      version_paste = Pasto::Paste.load(versioned_id)
      # Use the versioned content but keep access-controlled paste metadata
      paste_content = version_paste
    rescue
      halt env, 404
    end

    # Get current user
    current_user = Pasto.get_current_user(env)

    # Get all theme-related template variables
    theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)

    # Generate highlighted content from versioned paste
    highlighted_content = paste_content.highlight(nil)[0]

    # Version count for the history button (owner can see history)
    version_count = 0
    if current_user && paste.user_id == current_user.sepia_id
      version_count = Pasto::Paste.versions(id).size
    end

    # Set template variables
    is_home_page = false
    page_title = paste.display_title
    is_version_view = true
    base_paste_id = id

    # Generate social media metadata for version view
    meta_title = "#{paste.display_title} (v#{paste.generation})"
    meta_description = generate_meta_description(paste.content)
    host = env.request.headers["Host"]? || "localhost:3000"
    meta_url = "http://#{host}#{env.request.path}"
    meta_image = "http://#{host}/preview/#{paste.sepia_id}.png"

    content = render "src/views/show.ecr"
    render "src/views/layout.ecr"
  end

  # Error handling for other 404 cases
  error 404 do |env|
    current_user = Pasto.get_current_user(env)
    theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)
    page_title = "404 - Not Found"
    is_home_page = false

    # Social media metadata
    meta_title = "404 - Not Found - Pasto"
    meta_description = "The requested paste could not be found on Pasto"
    meta_url = "/404"
    meta_image = "/favicon.png"

    # Set 404 status code
    env.response.status_code = 404

    reason = "not_found"

    content = render "src/views/404.ecr"
    render "src/views/layout.ecr"
  end

  # Error handling for 403 Forbidden cases
  error 403 do |env|
    current_user = Pasto.get_current_user(env)
    theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)
    page_title = "403 - Access Denied"
    is_home_page = false

    # Social media metadata
    meta_title = "403 - Access Denied - Pasto"
    meta_description = "Access to this paste is restricted"
    meta_url = "/403"
    meta_image = "/favicon.png"

    # Set 403 status code
    env.response.status_code = 403

    reason = "access_denied"

    content = render "src/views/403.ecr"
    render "src/views/layout.ecr"
  end

  # Preview image route for social media cards (must come before catch-all routes)
  get "/preview/:id" do |env|
    # Rate limiting for preview generation (use existing highlight limiter)
    allowed, rate_limit_response = Pasto::RateLimitHelper.check_and_handle_rate_limit(env, :highlight)
    unless allowed
      next "Rate limit exceeded for preview generation"
    end

    # Validate access using centralized function
    access = Pasto.validate_paste_access(env)

    unless access.allowed?
      halt env, access.status_code
    end

    if access.paste
      paste = access.paste.as(Pasto::Paste)
    else
      # Generate and serve 404 placeholder
      placeholder_path = generate_placeholder_file("Paste not found")
      env.response.status_code = 404
      env.response.headers["Cache-Control"] = "public, max-age=300" # 5 minutes for errors
      next send_file env, placeholder_path
    end

    cache_path = PreviewGenerator.get_cache_path(paste.sepia_id)

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

  # Raw paste endpoint
  get "/:id/raw" do |env|
    id = env.params.url["id"]

    # Load the paste
    paste = Pasto::Paste.from_file(id)
    if paste.nil?
      halt env, 404
    end

    # Note: For burn-after-reading pastes in raw endpoint, we'll increment after sending content

    # Check access permissions using the centralized validation function
    access_result = Pasto.validate_paste_access(env)
    unless access_result.success?
      halt env, access_result.status_code
    end

    # Set content type and filename using Crystal's MIME module
    filename = Pasto::MimeTypes.generate_filename(paste)
    mime_type = MIME.from_filename(filename) || "text/plain"

    # Ensure charset is included for text types
    if mime_type.starts_with?("text/")
      mime_type += "; charset=utf-8"
    end

    env.response.content_type = mime_type
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

        # Store extension for language mapping after access control
        stored_ext = ext
      end
    end

    # Validate access using centralized function
    access = Pasto.validate_paste_access(env)

    unless access.allowed?
      halt env, access.status_code
    end

    if access.paste
      paste = access.paste.as(Pasto::Paste)
    else
      halt env, 404
    end

    # Get current user for theme setup
    current_user = Pasto.get_current_user(env)

    # Apply language mapping from stored extension if present
    if stored_ext
      language_override = paste.language_for_extension(stored_ext)
    end

    # Note: For burn-after-reading pastes, we'll increment the view count AFTER showing the content
    # This ensures the user can see the paste once before it gets deleted

    # Get all theme-related template variables
    theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)

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

  # Serve syntax highlighting CSS for specific theme family and variant
  get "/syntax/:family/:variant" do |env|
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
      enhanced_css
    rescue ex
      env.response.status_code = 404
      env.response.content_type = "text/plain"
      "Theme not found: #{theme_name}"
    end
  end

  # Cache test endpoint for testing middleware caching
  get "/api/cache-test" do |_|
    timestamp = Time.utc.to_unix_ms
    response_body = "Cache test timestamp: #{timestamp}"
    response_body
  end
end
