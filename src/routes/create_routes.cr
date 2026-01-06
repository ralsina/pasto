require "../paste"
require "../theme_helper"
require "../time_helper"
require "../logging"
require "../rate_limit_helper"
require "../preview_generator"
require "../mimetypes"

module Pasto
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
    property encryption_salt : String?
    property encryption_iterations : Int32
    property user_id : String?
    property? anonymous : Bool

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
      @anonymous = env.params.body["anonymous"]?.to_s == "true"

      # Handle encryption fields
      @is_encrypted = env.params.body["is_encrypted"]?.to_s == "true"
      @encryption_iv = env.params.body["encryption_iv"]?.to_s.strip.empty? ? nil : env.params.body["encryption_iv"]?.to_s

      # Handle encryption fields (always password-based now)
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

    # Auto-detect language if not specified
    if params.language.nil? || params.language.to_s.strip.empty?
      detected = Paste.get_best_supported_language(paste.content)
      paste.language = detected || "text"
    else
      paste.language = params.language
    end

    paste.title = params.title
    paste.theme = params.syntax_theme
    # Only set user_id if not anonymous (even for logged-in users)
    paste.user_id = params.anonymous? ? nil : params.user_id
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
      paste.encryption_salt = params.encryption_salt
      paste.encryption_iterations = params.encryption_iterations
      paste.content = "" # Clear regular content for encrypted pastes
    end
  end

  # Register all create-related routes
  def self.register_create_routes
    base_path = Pasto.config.base_path

    # Create paste form (home page)
    get Pasto::PathHelper.with_base_path("/", base_path) do |env|
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
    post Pasto::PathHelper.with_base_path("/highlight", base_path) do |env|
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

    # API endpoint for language detection
    post Pasto::PathHelper.with_base_path("/api/detect-language", base_path) do |env|
      # Rate limit check for language detection endpoint
      allowed, rate_limit_response = Pasto::RateLimitHelper.check_and_handle_rate_limit(env, :highlight)
      unless allowed
        next rate_limit_response
      end

      # Get content from request
      content = env.params.body["content"]?.to_s
      if content.empty?
        env.response.content_type = "application/json"
        next {
          "language"   => nil,
          "confidence" => 0.0,
        }.to_json
      end

      # Detect language using Hansa + Tartrazine
      detected_language = Pasto::Paste.get_best_supported_language(content)

      # Return detected language
      env.response.content_type = "application/json"
      {
        "language" => detected_language,
      }.to_json
    rescue ex
      Pasto::Logging.error("Language detection failed: #{ex.message}")
      env.response.content_type = "application/json"
      {
        "language" => nil,
      }.to_json
    end

    # Handle paste submission (create new paste)
    post Pasto::PathHelper.with_base_path("/", base_path) do |env|
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

      # Prevent anonymous private pastes (even for logged-in users)
      if params.is_private? && params.anonymous?
        env.response.status_code = 403
        next "Anonymous pastes cannot be private"
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
        # If user has SSH keys and this is not an anonymous paste, add paste to their first key for consistency
        if current_user && !current_user.keys.empty? && !params.anonymous?
          ssh_key = current_user.keys.first
          paste.ssh_fingerprint = ssh_key.sepia_id
          paste.save
          ssh_key.add_paste(paste)
          ssh_key.save
          Logging.info("Paste #{paste.sepia_id} associated with user #{current_user.sepia_id} via SSH key #{ssh_key.sepia_id}")
        else
          if current_user.nil?
            Logging.warn("Paste #{paste.sepia_id} not associated: no current_user")
          elsif current_user.keys.empty?
            Logging.warn("Paste #{paste.sepia_id} not associated: user has no SSH keys (keys count: #{current_user.keys.size})")
          elsif params.anonymous?
            Logging.warn("Paste #{paste.sepia_id} not associated: anonymous=true")
          end
        end

        # Invalidate any existing cache for this paste
        Pasto::Cache.invalidate(paste.sepia_id)

        # Return JSON response with paste URL
        env.response.content_type = "application/json"
        {
          "success"      => true,
          "url"          => Pasto.build_paste_url(env, paste.sepia_id),
          "id"           => paste.sepia_id,
          "is_view_once" => paste.burn_after_reading?,
        }.to_json
      else
        env.response.status_code = 500
        "Failed to save paste"
      end
    end
  end
end
