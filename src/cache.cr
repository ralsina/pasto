require "kemal-cache"

# Cache management for Pasto application
module Pasto
  # Cache wrapper that uses Kemal::Cache for automatic HTTP caching
  class Cache
    @@cache_config : Kemal::Cache::Config?
    @@cache_dir : String = "./public/cache"

    def self.cache_dir=(dir : String)
      @@cache_dir = dir
    end

    def self.cache_dir
      @@cache_dir
    end

    # Initialize the cache configuration
    def self.init(cache_dir : String, default_ttl : Int32 = 3600)
      @@cache_dir = cache_dir
      Dir.mkdir_p(cache_dir)

      # Create Kemal::Cache config with MemoryStore
      # kemal-cache has built-in security: it skips caching for requests with
      # Authorization headers, Cookie headers, or responses with Set-Cookie
      @@cache_config = Kemal::Cache::Config.new(
        expires_in: default_ttl.seconds,
        store: Kemal::Cache::MemoryStore.new
      )
    end

    # Get the cache config instance
    def self.config : Kemal::Cache::Config
      if config = @@cache_config
        config
      else
        init(@@cache_dir)
        @@cache_config ||= Kemal::Cache::Config.new(expires_in: 3600.seconds)
      end
    end

    # Invalidate cache entries
    # Since we use MemoryStore without prefix support, we clear the entire cache
    def self.invalidate(id : String) : Bool
      store = config.store
      store.clear
      true
    rescue
      false
    end
  end

  # Initialize cache directory in the main app
  def self.init_cache(cache_dir : String)
    Cache.init(cache_dir)
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
    # Generate simple placeholder using Tartrazine with a message
    # New API uses TTF fonts (JetBrains Mono) for much better quality
    placeholder_content = "// Error: #{message}\n"

    # Create PNG formatter with default TTF font
    formatter = Tartrazine::Png.new(
      theme: Tartrazine.theme("default-dark"),
      line_numbers: false,
      font_size: 24 # Large font for better preview images
    )

    buf = IO::Memory.new
    formatter.format(placeholder_content, Tartrazine.lexer(name: "text"), buf)

    # Add rounded corners for better appearance
    img_io = IO::Memory.new(buf.to_s)
    img = CrImage::PNG.read(img_io)
    img = img.round_corners(15) # Add rounded corners (15px radius)

    # Convert back to PNG and save
    output = IO::Memory.new
    CrImage::PNG.write(output, img)
    File.write(filename, output.to_s)
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
