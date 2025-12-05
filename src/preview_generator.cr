require "tartrazine"

class PreviewGenerator
  def self.generate_preview_image(paste : Pasto::Paste) : String
    # Extract first 5 lines for preview
    lines = paste.content.lines.first(5)
    preview_content = lines.join("\n")

    # Extract baked spleen font to temporary file
    temp_font_path = extract_spleen_font

    # Create PNG formatter manually to set font size for spleen-32x64.pcf
    formatter = Tartrazine::Png.new(
      theme: Tartrazine.theme("monokai"),
      line_numbers: false,
      font_path: temp_font_path,
      font_width: 32, # Match the spleen-32x64 font width
      font_height: 64 # Match the spleen-32x64 font height
    )

    buf = IO::Memory.new
    formatter.format(preview_content, Tartrazine.lexer(name: paste.language || "text"), buf)
    buf.to_s
  ensure
    # Clean up temporary font file
    File.delete(temp_font_path) if temp_font_path && File.exists?(temp_font_path)
  end

  def self.extract_spleen_font : String
    # Create temp directory for fonts
    temp_dir = File.join(Dir.tempdir, "pasto_fonts")
    Dir.mkdir_p(temp_dir) unless Dir.exists?(temp_dir)

    # Extract the baked spleen font to temp file
    temp_font_path = File.join(temp_dir, "spleen-32x64.pcf")

    unless File.exists?(temp_font_path)
      font_data = PastoAssets.get("fonts/spleen-32x64.pcf")
      File.write(temp_font_path, font_data)
    end

    temp_font_path
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
