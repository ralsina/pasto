require "file_utils"

# Cache management for Pasto application
module Pasto
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
