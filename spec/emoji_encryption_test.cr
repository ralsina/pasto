require "./spec_helper"
require "../src/gcm_fix"

describe "Emoji and Unicode Encryption" do
  describe "Full roundtrip encryption/decryption" do
    it "handles emoji and Unicode characters correctly" do
      # Test complex Unicode string with emoji, Chinese, Arabic, Cyrillic, and accented Latin
      original_text = "🔐🚀 Secret message with Unicode: 中文 العربية русский ñáéíóú 漢字 한국어"

      key = Base64.strict_encode("01234567890123456789012345678901")
      iv = Base64.strict_encode("012345678901")

      # Test encryption
      encrypted = encrypt_for_pasto_webcrypto(original_text, key, iv)

      # Verify encrypted output is valid
      encrypted.should_not be_empty
      encrypted.should_not eq(original_text)

      # Verify encrypted data is larger than plaintext (includes auth tag)
      encrypted_bytes = Base64.decode(encrypted)
      encrypted_bytes.size.should be > original_text.bytesize

      # Verify consistent output
      encrypted2 = encrypt_for_pasto_webcrypto(original_text, key, iv)
      encrypted.should eq(encrypted2)

      # Test decryption using the web-compatible approach
      # Split encrypted data into ciphertext and auth tag (last 16 bytes)
      encrypted_bytes = Base64.decode(encrypted)
      ciphertext = encrypted_bytes[0, encrypted_bytes.size - 16]
      auth_tag = encrypted_bytes[-16, 16]

      # Setup decryption cipher
      decipher = OpenSSL::Cipher.new("aes-256-gcm")
      decipher.decrypt
      decipher.key = Base64.decode(key)
      decipher.iv = Base64.decode(iv)

      # Set the authentication tag
      decipher.gcm_auth_tag = auth_tag

      # Decrypt
      decrypted_bytes = decipher.update(ciphertext) + decipher.final
      decrypted_text = String.new(decrypted_bytes)

      # Verify roundtrip success
      decrypted_text.should eq(original_text)
    end

    it "handles edge case Unicode strings" do
      test_cases = [
        "🔐", # Single emoji
        "中文", # Chinese characters
        "العربية", # Arabic text
        "русский", # Cyrillic text
        "ñáéíóú", # Accented Latin
        "", # Empty string
        "🌍🚀🔒💻📱", # Multiple emojis
        "Mixed text: 🌍 English 中文 العربية русский", # Mixed content
      ]

      key = Base64.strict_encode("01234567890123456789012345678901")
      iv = Base64.strict_encode("012345678901")

      test_cases.each do |test_text|
        # Encrypt
        encrypted = encrypt_for_pasto_webcrypto(test_text, key, iv)
        encrypted.should_not be_empty

        # Decrypt
        encrypted_bytes = Base64.decode(encrypted)
        ciphertext = encrypted_bytes[0, encrypted_bytes.size - 16]
        auth_tag = encrypted_bytes[-16, 16]

        decipher = OpenSSL::Cipher.new("aes-256-gcm")
        decipher.decrypt
        decipher.key = Base64.decode(key)
        decipher.iv = Base64.decode(iv)
        decipher.gcm_auth_tag = auth_tag

        decrypted_bytes = decipher.update(ciphertext) + decipher.final
        decrypted_text = String.new(decrypted_bytes)

        decrypted_text.should eq(test_text), "Failed to roundtrip: #{test_text.inspect}"
      end
    end

    it "produces consistent output for Unicode content" do
      unicode_text = "🔐🚀 Test: 你好世界 مرحبا Привет мир"

      key = Base64.strict_encode("01234567890123456789012345678901")
      iv = Base64.strict_encode("012345678901")

      # Encrypt multiple times
      results = [] of String
      5.times do
        results << encrypt_for_pasto_webcrypto(unicode_text, key, iv)
      end

      # All results should be identical
      results.each do |result|
        result.should eq(results[0])
      end
    end
  end
end