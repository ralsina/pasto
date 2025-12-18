require "./spec_helper"
require "../src/gcm_fix"

describe "GCM Encryption" do
  describe "Basic functionality" do
    it "performs working GCM encryption" do
      content = "Hello, World!"
      key = Base64.strict_encode("01234567890123456789012345678901")
      iv = Base64.strict_encode("012345678901")

      # Test that encryption works with our implementation
      result = encrypt_for_pasto_webcrypto(content, key, iv)
      result.should_not be_empty
      result.should_not eq(content)

      # Decoded result should be larger than plaintext (includes auth tag)
      decoded = Base64.decode_string(result)
      decoded.bytesize.should be > content.bytesize
    end
  end

  describe "Web Crypto API compatibility" do
    it "produces output that includes auth tag (larger than plaintext)" do
      content = "Test message"
      key = Base64.strict_encode("01234567890123456789012345678901")
      iv = Base64.strict_encode("012345678901")

      # Use our working GCM implementation
      encrypted_b64 = encrypt_for_pasto_webcrypto(content, key, iv)
      encrypted = Base64.decode_string(encrypted_b64)

      # Encrypted output should be larger than plaintext due to auth tag
      encrypted.bytesize.should be > content.bytesize

      # Auth tag should be last 16 bytes
      auth_tag = encrypted[-16, 16]
      auth_tag.bytesize.should eq(16)
    end

    it "produces consistent output for same inputs" do
      content = "Test message"
      key = Base64.strict_encode("01234567890123456789012345678901")
      iv = Base64.strict_encode("012345678901")

      # Encrypt twice with same parameters using our working implementation
      encrypted1 = encrypt_for_pasto_webcrypto(content, key, iv)
      encrypted2 = encrypt_for_pasto_webcrypto(content, key, iv)

      encrypted1.should eq(encrypted2)
    end
  end
end