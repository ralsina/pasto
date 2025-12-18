require "file_utils"
require "json"

# Cache management for Pasto application
module Pasto
  # Cache entry metadata
  class CacheEntry
    property content : String
    property mime_type : String
    property created_at : Time
    property ttl : Int32? # Time to live in seconds, nil means no expiration

    def initialize(@content : String, @mime_type : String, @ttl : Int32? = nil)
      @created_at = Time.utc
    end

    def expired? : Bool
      return false unless ttl_val = ttl
      (Time.utc - @created_at).total_seconds > ttl_val
    end

    def to_json : String
      {
        content:    @content,
        mime_type:  @mime_type,
        created_at: @created_at.to_unix,
        ttl:        @ttl,
      }.to_json
    end

    def self.from_json(json : String) : CacheEntry
      data = Hash(String, JSON::Any).from_json(json)
      content = data["content"].as_s
      mime_type = data["mime_type"].as_s
      created_at = Time.unix(data["created_at"].as_i)
      ttl = data["ttl"]?.try(&.as_i?)

      entry = CacheEntry.new(content, mime_type, ttl)
      entry.created_at = created_at
      entry
    end
  end

  # Cache configuration for endpoints
  struct CacheConfig
    property path_regex : Regex
    property mime_type : String
    property ttl : Int32?

    def initialize(@path_regex : Regex, @mime_type : String, @ttl : Int32? = nil)
    end
  end

  class Cache
    @@cache_dir : String = "./public/cache"
    @@cache_configs = [] of CacheConfig

    def self.cache_dir=(dir : String)
      @@cache_dir = dir
    end

    def self.cache_dir
      @@cache_dir
    end

    def self.cache_configs
      @@cache_configs
    end

    def self.add_cache_config(path_regex : Regex, mime_type : String, ttl : Int32? = nil)
      @@cache_configs << CacheConfig.new(path_regex, mime_type, ttl)
    end

    def self.find_cache_config(path : String) : CacheConfig?
      @@cache_configs.find(&.path_regex.matches?(path))
    end

    # Enhanced cache methods with metadata support
    def self.get(key : String) : CacheEntry?
      file_path = File.join(@@cache_dir, "#{key}.cache")
      return nil unless File.exists?(file_path)

      begin
        json = File.read(file_path)
        entry = CacheEntry.from_json(json)
        return nil if entry.expired?
        entry
      rescue
        nil
      end
    end

    def self.set(key : String, content : String, mime_type : String, ttl : Int32? = nil) : Bool
      file_path = File.join(@@cache_dir, "#{key}.cache")

      begin
        entry = CacheEntry.new(content, mime_type, ttl)
        File.write(file_path, entry.to_json)
        true
      rescue
        false
      end
    end

    def self.invalidate(id : String) : Bool
      pattern = File.join(@@cache_dir, "#{id}*.cache")

      begin
        Dir.glob(pattern).each do |file|
          File.delete(file)
        end
        true
      rescue
        false
      end
    end

    # Generate cache key from request
    def self.generate_cache_key(env) : String
      path = env.request.path
      method = env.request.method
      query = env.request.query_params.to_a.sort_by(&.first.[](0)).map { |k, v| "#{k}=#{v}" }.join("&")

      # Include request body hash for POST/PUT requests
      body_hash = ""
      if env.request.method.in?("POST", "PUT") && env.request.body
        body = env.request.body.not_nil!.gets_to_end
        body_hash = OpenSSL::Digest.new("sha256").update(body).final.hexstring[0..15]
        # Reset body for downstream handlers
        env.request.body = IO::Memory.new(body)
      end

      key_data = "#{method}:#{path}:#{query}:#{body_hash}"
      OpenSSL::Digest.new("sha256").update(key_data).final.hexstring
    end
  end

  # Initialize cache directory in the main app
  def self.init_cache(cache_dir : String)
    Cache.cache_dir = cache_dir
    Dir.mkdir_p(cache_dir)
  end
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

# Helper function to generate and save placeholder preview images
def generate_placeholder_file(message : String) : String
  # Create cache directory for placeholders
  placeholder_dir = "./public/cache/placeholders"
  Dir.mkdir_p(placeholder_dir) unless Dir.exists?(placeholder_dir)

  # Generate filename based on message hash
  message_hash = message.gsub(/[^a-zA-Z0-9]/, "_").downcase
  filename = File.join(placeholder_dir, "#{message_hash}.png")

  # Generate if doesn't exist
  unless File.exists?(filename)
    # Generate simple placeholder using Tartrazine with a message and baked spleen font
    placeholder_content = "// Error: #{message}\n"

    # Extract baked spleen font to temporary file
    temp_dir = File.join(Dir.tempdir, "pasto_fonts")
    Dir.mkdir_p(temp_dir) unless Dir.exists?(temp_dir)
    temp_font_path = File.join(temp_dir, "spleen-32x64.pcf")

    unless File.exists?(temp_font_path)
      font_data = Pasto::PastoAssets.get("fonts/spleen-32x64.pcf")
      File.write(temp_font_path, font_data)
    end

    # Create PNG formatter manually to set font size for spleen-32x64.pcf
    formatter = Tartrazine::Png.new(
      theme: Tartrazine.theme("default-dark"),
      line_numbers: false,
      font_path: temp_font_path,
      font_width: 32, # Match the spleen-32x64 font width
      font_height: 64 # Match the spleen-32x64 font height
    )

    buf = IO::Memory.new
    formatter.format(placeholder_content, Tartrazine.lexer(name: "text"), buf)
    png_bytes = buf.to_s
    File.write(filename, png_bytes)

    # Clean up temporary font file
    File.delete(temp_font_path) if temp_font_path && File.exists?(temp_font_path)
  end
  filename
end

# Helper function to generate meta descriptions from paste content
def generate_meta_description(content : String) : String
  lines = content.lines
  description_lines = lines.reject(&.strip.empty?).first(3)

  description = description_lines.join(" ").strip

  # Clean up the description
  description = description.gsub(/\s+/, " ")      # Normalize whitespace
  description = description.gsub(/^[#\s]+/, "")   # Remove comment symbols
  description = description.gsub(/[{}[\]()]/, "") # Remove brackets

  # Limit to 200 characters and add ellipsis if truncated
  if description.size > 200
    description = description[0..197] + "..."
  end

  description.empty? ? "A code snippet shared on Pasto" : description
end
