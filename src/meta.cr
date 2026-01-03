# Helper functions for meta tag generation

require "crimage"
require "tartrazine"

# Generate meta description from paste content for SEO/social sharing
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

# Generate and save placeholder preview image for error states
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
