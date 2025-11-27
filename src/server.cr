require "kemal"
require "http"
require "file_utils"
require "rate_limiter"
require "tartrazine"
require "./paste"

module Pasto
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

# Set up Kemal routes
before_all do |env|
  env.response.headers["X-Content-Type-Options"] = "nosniff"
  env.response.headers["X-Frame-Options"] = "DENY"
  env.response.headers["X-XSS-Protection"] = "1; mode=block"
end

# Main page - paste creation form
get "/" do |env|
  # Get saved theme preferences or use defaults (used in ECR template)
  saved_pico_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"             # ameba:disable Lint/UselessAssign
  saved_pico_color = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"            # ameba:disable Lint/UselessAssign
  saved_syntax_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default-dark" # ameba:disable Lint/UselessAssign

  # Set additional variables needed by templates (used in ECR template)
  is_home_page = true  # ameba:disable Lint/UselessAssign
  page_title = "Pasto" # ameba:disable Lint/UselessAssign

  content = render "src/views/index.ecr" # ameba:disable Lint/UselessAssign
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

  paste = Pasto::Paste.new(content, language, syntax_theme)

  if paste.save
    # Invalidate any existing cache for this paste
    Pasto::Cache.invalidate(paste.sepia_id)

    # Redirect to the paste view
    env.redirect "/#{paste.sepia_id}"
  else
    env.response.status_code = 500
    "Failed to save paste"
  end
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

  # Get saved theme preferences or use defaults (used in ECR template)
  saved_pico_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"             # ameba:disable Lint/UselessAssign
  saved_pico_color = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"            # ameba:disable Lint/UselessAssign
  saved_syntax_theme = env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default-dark" # ameba:disable Lint/UselessAssign

  # Get language override from URL parameter if present
  url_lang_override = env.params.query["lang"]?
  if url_lang_override && !url_lang_override.empty?
    language_override = url_lang_override
  end

  # Generate highlighted content (used in ECR template)
  highlighted_content = paste.highlight(language_override)[0] # ameba:disable Lint/UselessAssign

  # Set additional variables needed by templates (used in ECR template)
  is_home_page = false                   # ameba:disable Lint/UselessAssign
  page_title = "Paste #{paste.sepia_id}" # ameba:disable Lint/UselessAssign

  content = render "src/views/show.ecr" # ameba:disable Lint/UselessAssign
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
