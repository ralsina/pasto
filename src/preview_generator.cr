require "tartrazine"
require "./assets"

class PreviewGenerator
  def self.generate_preview_image(paste : Pasto::Paste) : String
    # Handle special cases first
    if paste.burn_after_reading?
      preview_content = "🔥 Burn After Reading"
    elsif paste.private?
      preview_content = "🔒 Private Paste"
    elsif paste.is_encrypted? && paste.content.empty?
      preview_content = "🔐 Encrypted Content"
    else
      # Extract first 5 lines for preview
      lines = paste.content.lines.first(5)
      preview_content = lines.join("\n")
    end

    # Use new tartrazine API with TTF font (JetBrains Mono by default)
    # Font size is in points, much better quality than old PCF fonts
    formatter = Tartrazine::Png.new(
      theme: Tartrazine.theme(paste.theme),
      line_numbers: false,
      font_size: 24 # Large font for better preview images
    )

    buf = IO::Memory.new
    formatter.format(preview_content, Tartrazine.lexer(name: paste.language || "text"), buf)

    # Add rounded corners to preview image for better appearance
    img_io = IO::Memory.new(buf.to_s)
    img = CrImage::PNG.read(img_io)
    img = img.round_corners(15) # Add rounded corners (15px radius)

    # Convert back to PNG bytes
    output = IO::Memory.new
    CrImage::PNG.write(output, img)
    output.to_s
  end

  def self.save_preview_image(paste : Pasto::Paste, filename : String) : String
    png_bytes = generate_preview_image(paste)
    File.write(filename, png_bytes)
    filename
  end

  def self.get_cache_path(paste_id : String) : String
    cache_dir = "./public/cache/previews"
    Dir.mkdir_p(cache_dir) unless Dir.exists?(cache_dir)
    File.join(cache_dir, "#{paste_id}.png")
  end
end
