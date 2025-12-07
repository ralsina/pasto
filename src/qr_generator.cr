require "qr-code"
require "base64"
require "stumpy_png"

module Pasto
  class QRGenerator
    # Generate QR code for an encrypted paste containing URL and encryption key
    def self.generate_encrypted_paste_qr(url : String, encryption_key : String) : String
      # Create the QR code data as a compact format: url|key
      qr_data = "#{url}|#{encryption_key}"

      # Generate QR code
      qr = QRCode.new(qr_data)

      # Convert QR code to PNG using the library's built-in methods
      # The qr-code library should have a method to convert to PNG
      # For now, let's create a simple SVG-based QR code
      svg = qr.to_s

      # Convert SVG to base64 for embedding in HTML
      base64_svg = Base64.strict_encode(svg)

      # Return as data URL
      "data:image/svg+xml;base64,#{base64_svg}"
    rescue ex
      puts "QR generation failed: #{ex.message}"
      # Return empty string on error
      ""
    end

    # Generate QR code for just the URL (for non-encrypted pastes)
    def self.generate_url_qr(url : String) : String
      qr = QRCode.new(url)
      svg = qr.to_s
      base64_svg = Base64.strict_encode(svg)
      "data:image/svg+xml;base64,#{base64_svg}"
    rescue ex
      puts "QR generation failed: #{ex.message}"
      ""
    end

    # Generate QR code PNG as base64 data URL
    def self.generate_url_png(url : String) : String
      qr = QRCode.new(url)

      # Generate PNG using StumpyPNG
      canvas = qr.as_png
      png_data = StumpyPNG.export(canvas)

      # Convert to base64 data URL
      base64_png = Base64.strict_encode(png_data)
      "data:image/png;base64,#{base64_png}"
    rescue ex
      puts "QR generation failed: #{ex.message}"
      ""
    end

    # Generate QR code for sharing the encrypted paste with both URL and key
    def self.generate_shareable_qr(base_url : String, paste_id : String, encryption_key : String? = nil) : String
      url = "#{base_url}/#{paste_id}"

      if encryption_key
        generate_encrypted_paste_qr(url, encryption_key)
      else
        generate_url_qr(url)
      end
    end
  end
end
