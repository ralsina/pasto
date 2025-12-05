require "tartrazine"

class PreviewGenerator
  def self.generate_preview_image(paste : Pasto::Paste) : String
    # Extract first 5 lines for preview
    lines = paste.content.lines.first(5)
    preview_content = lines.join("\n")

    # Use Tartrazine's built-in PNG formatter with monokai theme
    Tartrazine.to_png(
      preview_content,
      paste.language || "text",
      "monokai",
      line_numbers: false
    )
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
