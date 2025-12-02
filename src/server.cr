require "kemal"
require "http"
require "file_utils"
require "rate_limiter"
require "tartrazine"
require "ecr"
require "kemal-session"
require "./paste"
require "./user_session"
require "./models/user"
require "./models/auth_token"
require "./models/ssh_key"

module Pasto
  # Helper to validate session and get current user
  def self.get_current_user(env) : User?
    user_session = env.session.object?("user").as(Pasto::UserSession?)
    return nil unless user_session

    # Check if session has expired
    return nil if user_session.expired?

    # Update last accessed time
    user_session.touch
    env.session.object("user", user_session)

    # Get user from database
    User.find(user_session.user_id)
  end

  # Simple rate limiter for paste creation
  class RateLimit
    @@limiter = RateLimiter.new(10, 60)
    @@mutex = Mutex.new

    def self.allow?(key : String) : Bool
      @@mutex.synchronize do
        @@limiter.allow?(key)
      end
    end
  end

  class Cache
    @@cache_dir : String = "./public/cache"

    def self.cache_dir=(dir : String)
      @@cache_dir = dir
    end

    def self.cache_dir
      @@cache_dir
    end

    def self.get(key : String) : String?
      file_path = File.join(@@cache_dir, "#{key}.html")
      return nil unless File.exists?(file_path)

      begin
        File.read(file_path)
      rescue
        nil
      end
    end

    def self.set(key : String, content : String) : Bool
      file_path = File.join(@@cache_dir, "#{key}.html")

      begin
        File.write(file_path, content)
        true
      rescue
        false
      end
    end

    def self.invalidate(id : String) : Bool
      pattern = File.join(@@cache_dir, "#{id}*.html")

      begin
        Dir.glob(pattern).each do |file|
          File.delete(file)
        end
        true
      rescue
        false
      end
    end
  end
end

# Add security headers to all requests
before_all do |env|
  env.response.headers["X-Content-Type-Options"] = "nosniff"
  env.response.headers["X-Frame-Options"] = "DENY"
  env.response.headers["X-XSS-Protection"] = "1; mode=block"
end

# Logout route - clear session
post "/logout" do |env|
  # Clear the session using kemal-session
  env.session.destroy

  puts "User logged out"

  env.redirect "/?logout=success"
end

# Update user profile
post "/profile" do |env|
  current_user = Pasto.get_current_user(env)

  unless current_user
    env.response.status_code = 401
    next "Unauthorized"
  end

  # Check if this is an AJAX request (for theme updates)
  is_ajax = env.request.headers["X-Requested-With"]? == "XMLHttpRequest"

  # Get the new name from form
  if env.params.body.has_key?("name")
    new_name = env.params.body["name"]?.try(&.strip)
    if new_name && !new_name.empty?
      new_name = new_name.gsub(/<[^>]*>/, "")  # Remove HTML tags
      new_name = new_name[0..50]  # Limit to 50 chars
      current_user.name = new_name
    else
      current_user.name = nil
    end
  end

  # Update theme preferences
  if env.params.body.has_key?("pico_theme")
    current_user.pico_theme = env.params.body["pico_theme"]?.try(&.strip)
  end
  if env.params.body.has_key?("pico_color")
    current_user.pico_color = env.params.body["pico_color"]?.try(&.strip)
  end
  if env.params.body.has_key?("syntax_theme")
    current_user.syntax_theme = env.params.body["syntax_theme"]?.try(&.strip)
  end

  if current_user.save
    puts "User #{current_user.sepia_id} updated"
    if is_ajax
      env.response.content_type = "application/json"
      next {"status" => "ok"}.to_json
    else
      env.redirect "/profile?updated=true"
    end
  else
    if is_ajax
      env.response.status_code = 500
      env.response.content_type = "application/json"
      next {"status" => "error"}.to_json
    else
      env.redirect "/profile?error=save_failed"
    end
  end
end

# SSH Auth token route - validate token and create session
get "/auth/:token" do |env|
  token_id = env.params.url["token"]
  ip_address = env.request.headers["X-Forwarded-For"]? || env.request.headers["X-Real-IP"]? || env.request.remote_address.to_s

  token = Pasto::AuthToken.find(token_id)

  if token.nil? || token.expired?
    # Delete expired token if it exists
    token.try(&.delete)

    env.response.status_code = 404
    # ameba:disable Lint/UselessAssign
    saved_pico_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
    saved_pico_color = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
    saved_syntax_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default-dark"
    current_user = nil
    is_home_page = false
    page_title = "Invalid Token"

    content = <<-HTML
      <hgroup>
        <h2>Invalid or Expired Token</h2>
        <p>The login token is invalid, expired, or has already been used.</p>
        <p>Please run <code>ssh -p PORT host login</code> again to get a new token.</p>
      </hgroup>
      <a href="/">Return to Pasto</a>
    HTML
    next render "src/views/layout.ecr"
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
    user.save  # Save first to get sepia_id
    user.add_key(ssh_key)  # This sets owner_id and adds to keys array
    user.save  # Save again with the key added
    puts "Created new user #{user.sepia_id} for SSH key #{token.fingerprint}"
  else
    # Make sure the key is in the user's keys array (in case of data inconsistency)
    unless user.keys.any? { |k| k.sepia_id == ssh_key.sepia_id }
      user.add_key(ssh_key)
      user.save
      puts "Added SSH key #{token.fingerprint} to existing user #{user.sepia_id}"
    end
    puts "Existing user #{user.sepia_id} logging in via SSH key #{token.fingerprint}"
  end

  # Create session
  user_session = Pasto::UserSession.new(user.sepia_id, nil, ip_address)
  env.session.object("user", user_session)

  # Delete the token (one-time use)
  token.delete

  puts "SSH auth successful for user #{user.sepia_id} from #{ip_address}"

  # Redirect to home with success message
  env.redirect "/?login=success"
end

# User profile page
get "/profile" do |env|
  # Validate session to get current user
  # ameba:disable Lint/UselessAssign
  current_user = Pasto.get_current_user(env)

  # Get SSH connection info from config
  config = Pasto.config
  # ameba:disable Lint/UselessAssign
  ssh_host = config.try(&.bind) || "localhost"
  # Use base_url host if bind is 0.0.0.0
  if ssh_host == "0.0.0.0" && config
    # Extract host from base_url
    base_url = config.base_url
    if match = base_url.match(%r{https?://([^:/]+)})
      ssh_host = match[1]
    else
      ssh_host = "localhost"
    end
  end
  # ameba:disable Lint/UselessAssign
  ssh_port = config.try(&.ssh_port) || 2222
  # ameba:disable Lint/UselessAssign
  ssh_enabled = config.try(&.ssh_enabled) || false

  # Get saved theme preferences or use defaults
  # ameba:disable Lint/UselessAssign
  saved_pico_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
  saved_pico_color = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
  saved_syntax_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default-dark"

  # Set template variables (ECR template will have access to these)
  # ameba:disable Lint/UselessAssign
  page_title = "Profile"
  is_home_page = false

  content = render "src/views/profile_content.ecr"
  render "src/views/layout.ecr"
end

# Main page - paste creation form
get "/" do |env|
  # ameba:disable Lint/UselessAssign
  # Validate session to get current user
  current_user = Pasto.get_current_user(env)

  # Get saved theme preferences or use defaults
  saved_pico_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
  saved_pico_color = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
  saved_syntax_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default-dark"

  # Check for login/logout messages
  login_message = env.params.query["login"]? == "success"
  logout_message = env.params.query["logout"]? == "success"

  # Set template variables (ECR template will have access to these)
  is_home_page = true
  page_title = "Pasto"

  content = render "src/views/index.ecr"
  render "src/views/layout.ecr"
end

# API endpoint for live syntax highlighting
post "/highlight" do |env|
  content = env.params.body["content"]?.to_s
  language = env.params.body["language"]?.to_s
  theme = env.params.body["theme"]?.to_s

  content = "" if content.nil? || content.empty?
  theme = "default-dark" if theme.empty?

  # Normalize line endings from \r\n and \r to \n
  content = content.gsub("\r\n", "\n").gsub("\r", "\n")

  # Handle language detection
  if language.empty? || language == "Auto-detect" || language == ""
    language = nil
  end

  if content.empty?
    env.response.content_type = "text/html"
    next "<pre><code>Start typing to see preview...</code></pre>"
  end

  begin
    paste = Pasto::Paste.new(content, language, theme)
    highlighted_content, _css = paste.highlight

    # Return JSON with both highlighted content and detected language
    env.response.content_type = "application/json"
    {
      "html"              => highlighted_content,
      "detected_language" => paste.language,
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

# Handle paste submission
post "/" do |env|
  # Rate limiting check
  client_ip = env.request.headers["X-Forwarded-For"]? || env.request.headers["X-Real-IP"]?
  if client_ip
    ip_key = client_ip.split(",")[0].strip # Take first IP if multiple
  else
    ip_key = env.request.remote_address.to_s
  end

  unless Pasto::RateLimit.allow?(ip_key)
    env.response.status_code = 429
    env.response.headers["Retry-After"] = "60"
    next "Rate limit exceeded. Please wait before creating another paste."
  end

  content = env.params.body["content"]?.to_s
  language = env.params.body["language"]?.to_s
  language = nil if language.empty?

  # Get title from form
  title = env.params.body["title"]?.to_s
  title = nil if title.strip.empty?

  # Get syntax theme from form or use default
  syntax_theme = env.params.body["syntax_theme"]?.to_s
  syntax_theme = "default-dark" if syntax_theme.empty?

  if content.empty?
    env.response.status_code = 400
    next "Content cannot be empty"
  end

  # Size validation
  config = Pasto.config
  if config.nil?
    env.response.status_code = 500
    next "Configuration not available"
  end

  content_bytesize = content.bytesize
  if content_bytesize > config.max_paste_size
    env.response.status_code = 413
    next "Paste too large. Maximum size is #{config.max_paste_size} bytes (got #{content_bytesize} bytes)."
  end

  # Get current user for ownership
  current_user = Pasto.get_current_user(env)
  user_id = current_user.try(&.sepia_id)

  paste = Pasto::Paste.new(content, language, syntax_theme, user_id: user_id, title: title)

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

    # Redirect to the paste view
    env.redirect "/#{paste.sepia_id}"
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
    env.response.status_code = 404
    next "Paste not found"
  end

  # Validate session to get current user
  current_user = Pasto.get_current_user(env)

  # Check ownership
  unless current_user && paste.user_id == current_user.sepia_id
    env.response.status_code = 403
    next "You don't have permission to edit this paste"
  end

  # Get saved theme preferences
  saved_pico_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
  saved_pico_color = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
  saved_syntax_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default-dark"

  # Set template variables
  is_home_page = false
  page_title = "Edit Paste #{paste.sepia_id}"

  content = render "src/views/edit.ecr"
  render "src/views/layout.ecr"
end

# Edit paste submission (POST)
post "/:id/edit" do |env|
  id = env.params.url["id"]

  paste = Pasto::Paste.from_file(id)
  if paste.nil?
    env.response.status_code = 404
    next "Paste not found"
  end

  # Validate session to get current user
  current_user = Pasto.get_current_user(env)

  # Check ownership
  unless current_user && paste.user_id == current_user.sepia_id
    env.response.status_code = 403
    next "You don't have permission to edit this paste"
  end

  new_content = env.params.body["content"]?.to_s
  new_language = env.params.body["language"]?.to_s
  new_language = nil if new_language.empty?

  new_title = env.params.body["title"]?.to_s
  new_title = nil if new_title.strip.empty?

  if new_content.empty?
    env.response.status_code = 400
    next "Content cannot be empty"
  end

  # Size validation
  config = Pasto.config
  if config.nil?
    env.response.status_code = 500
    next "Configuration not available"
  end

  content_bytesize = new_content.bytesize
  if content_bytesize > config.max_paste_size
    env.response.status_code = 413
    next "Paste too large. Maximum size is #{config.max_paste_size} bytes (got #{content_bytesize} bytes)."
  end

  # Update paste content (normalize line endings)
  paste.content = new_content.gsub("\r\n", "\n").gsub("\r", "\n")
  paste.language = new_language
  paste.title = new_title
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

  original_paste = Pasto::Paste.from_file(id)
  if original_paste.nil?
    env.response.status_code = 404
    next "Paste not found"
  end

  # Must be logged in to fork
  current_user = Pasto.get_current_user(env)
  unless current_user
    env.response.status_code = 401
    next "You must be logged in to fork a paste"
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

  paste = Pasto::Paste.from_file(id)
  if paste.nil?
    env.response.status_code = 404
    next "Paste not found"
  end

  # Must be logged in and own the paste
  current_user = Pasto.get_current_user(env)
  unless current_user && paste.user_id == current_user.sepia_id
    env.response.status_code = 403
    next "You don't have permission to delete this paste"
  end

  # Remove paste from user's SSH key pastes array
  if !current_user.keys.empty?
    current_user.keys.each do |ssh_key|
      ssh_key.pastes.reject! { |p| p.sepia_id == paste.sepia_id || p.base_id == paste.base_id }
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
  if base_paste = Pasto::Paste.from_file(base_id)
    Pasto::Cache.invalidate(base_id)
    Sepia::Storage.delete(base_paste)
  end

  env.redirect "/"
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
    env.response.status_code = 404
    next "Paste not found"
  end

  # Get current user for ownership check
  current_user = Pasto.get_current_user(env)
  
  # Check if user can see history (owner only for now)
  latest = versions.last
  unless current_user && latest.user_id == current_user.sepia_id
    env.response.status_code = 403
    next "Only the paste owner can view history"
  end

  # Get saved theme preferences
  saved_pico_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
  saved_pico_color = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
  saved_syntax_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default-dark"

  # Sort by generation (newest first)
  versions = versions.reverse

  # Set template variables
  is_home_page = false
  page_title = "History: #{latest.display_title}"

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

  # Get saved theme preferences
  saved_pico_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
  saved_pico_color = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
  saved_syntax_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default-dark"

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

  content = render "src/views/show.ecr"
  render "src/views/layout.ecr"
end

# View paste with specific language override via extension (more specific, comes first)
# Using a more explicit route pattern that matches files with extensions
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

      paste = Pasto::Paste.from_file(paste_id)
      if paste.nil?
        env.response.status_code = 404
        next "Paste not found"
      end

      # Map extension to language
      language_override = paste.language_for_extension(ext)
    end
  end

  # Load the paste (either with original id or modified id from extension handling)
  paste = Pasto::Paste.from_file(id)
  if paste.nil?
    env.response.status_code = 404
    next "Paste not found"
  end

  # ameba:disable Lint/UselessAssign
  # Validate session to get current user
  current_user = Pasto.get_current_user(env)

  # Get saved theme preferences or use defaults
  saved_pico_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
  saved_pico_color = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
  saved_syntax_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default-dark"

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

  content = render "src/views/show.ecr"
  render "src/views/layout.ecr"
end

# Serve static files from public directory
public_dir = "#{Dir.current}/public"
Kemal.config.public_folder = public_dir

# Serve syntax highlighting CSS
get "/syntax-theme.css" do |env|
  theme_name = env.params.query["theme"]? || "default-dark"

  begin
    formatter = Tartrazine::Html.new(theme: Tartrazine.theme(theme_name))
    css = formatter.style_defs

    env.response.content_type = "text/css"
    css
  rescue ex
    env.response.content_type = "text/css"
    "/* Error loading theme '#{theme_name}': #{ex.message} */"
  end
end

# Favicon handler - returns a simple paste icon
get "/favicon.ico" do |env|
  # Simple SVG paste icon (clipboard/paste symbol)
  favicon_svg = <<-SVG
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">
    <rect width="28" height="32" x="2" fill="#6466f1" rx="2"/>
    <rect width="24" height="28" x="4" y="2" fill="white" rx="1"/>
    <rect width="16" height="2" x="8" y="8" fill="#6466f1" rx="1"/>
    <rect width="12" height="2" x="8" y="12" fill="#6466f1" rx="1"/>
    <rect width="14" height="2" x="8" y="16" fill="#6466f1" rx="1"/>
    <rect width="10" height="2" x="8" y="20" fill="#6466f1" rx="1"/>
    <rect width="8" height="2" x="8" y="24" fill="#6466f1" rx="1"/>
  </svg>
  SVG

  # Convert SVG to ICO data (simplified - just serve as SVG with proper content type)
  env.response.content_type = "image/x-icon"
  favicon_svg
end

# Serve cached files directly if they exist
get "/cache/*" do |env|
  cache_path = env.params.url["path"]
  file_path = File.join(Pasto::Cache.cache_dir, cache_path)

  if File.exists?(file_path) && File.file?(file_path)
    send_file env, file_path
  else
    env.response.status_code = 404
    "Cached file not found"
  end
end

# Error handling
error 404 do |env|
  env.response.content_type = "text/html"
  <<-HTML
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Not Found - Pasto</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@1/css/pico.min.css">
  </head>
  <body>
    <main class="container">
      <hgroup>
        <h2>404 - Not Found</h2>
        <p>The requested paste could not be found.</p>
      </hgroup>
      <a href="/">Create a new paste</a>
    </main>
  </body>
  </html>
  HTML
end

# Initialize cache directory in the main app
module Pasto
  def self.init_cache(cache_dir : String)
    Cache.cache_dir = cache_dir
    Dir.mkdir_p(cache_dir)
  end
end
