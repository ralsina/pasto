require "tartrazine"
require "./paste"

module Pasto
  # MIME type and file extension mappings for improved downloads
  module MimeTypes
    # Get file extension for a language
    def self.get_file_extension(language : String?) : String
      return "txt" if language.nil? || language.empty?

      # Find matching Tartrazine lexer and get its extensions
      lexer = Tartrazine.lexer(name: language)
      exts = lexer.extensions
      exts.empty? ? "txt" : exts.first
    end

    # Generate appropriate filename for a paste
    def self.generate_filename(paste : Paste) : String
      # Use existing filename if available
      if paste_filename = paste.filename
        if !paste_filename.empty?
          return paste_filename
        end
      end

      # Generate from title if available
      if paste_title = paste.title
        if !paste_title.empty?
          title = paste_title
          # Sanitize title for filename
          sanitized = title.gsub(/[^a-zA-Z0-9\-_\s]/, "").strip
          sanitized = sanitized.gsub(/\s+/, "_")
          ext = get_file_extension(paste.language)
          return "#{sanitized}.#{ext}"
        end
      end

      # Generate from paste ID
      ext = get_file_extension(paste.language)
      "#{paste.sepia_id}.#{ext}"
    end
  end
end
