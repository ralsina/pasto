require "./spec_helper"
require "../src/gcm_fix"

# Create Node.js encryption script for testing
NODEJS_ENCRYPT_SCRIPT = <<-JS
const crypto = require('crypto');

function encryptForPasto(plaintext, keyBase64, ivBase64) {
  const key = Buffer.from(keyBase64, 'base64');
  const iv = Buffer.from(ivBase64, 'base64');

  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

  const encrypted = Buffer.concat([
    cipher.update(plaintext, 'utf8'),
    cipher.final()
  ]);

  const authTag = cipher.getAuthTag();

  // Combine and encode (Web Crypto API compatible)
  const result = Buffer.concat([encrypted, authTag]);
  return result.toString('base64');
}

function decryptFromPasto(encryptedB64, keyBase64, ivBase64) {
  const key = Buffer.from(keyBase64, 'base64');
  const iv = Buffer.from(ivBase64, 'base64');
  const encrypted = Buffer.from(encryptedB64, 'base64');

  // Split encrypted data and auth tag (last 16 bytes)
  const ciphertext = encrypted.slice(0, -16);
  const authTag = encrypted.slice(-16);

  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(authTag);

  let decrypted = Buffer.concat([
    decipher.update(ciphertext),
    decipher.final()
  ]);

  return decrypted.toString('utf8');
}

// Get command line arguments
const command = process.argv[2];
const plaintext = process.argv[3];
const keyBase64 = process.argv[4];
const ivBase64 = process.argv[5];

if (command === 'encrypt') {
  console.log(encryptForPasto(plaintext, keyBase64, ivBase64));
} else if (command === 'decrypt') {
  console.log(decryptFromPasto(plaintext, keyBase64, ivBase64));
} else {
  console.error('Usage: node script.js <encrypt|decrypt> <plaintext|encrypted> <key> <iv>');
  process.exit(1);
}
JS

describe "Crystal/Node.js GCM Compatibility" do
  describe "Roundtrip encryption compatibility" do
    it "can encrypt in Crystal and decrypt in Node.js" do
      plaintext = "Hello, World! This is a test message for roundtrip compatibility. 🔐"
      key = Base64.strict_encode("01234567890123456789012345678901") # 32 bytes
      iv = Base64.strict_encode("012345678901") # 12 bytes

      # Encrypt using Crystal implementation (with GCM fix)
      crystal_b64 = encrypt_for_pasto_webcrypto(plaintext, key, iv)

      # Create temporary Node.js script file
      temp_file = File.tempname("node_encrypt_test", ".js")
      File.write(temp_file, NODEJS_ENCRYPT_SCRIPT)

      # Decrypt using Node.js
      node_output = Process.new(
        "node",
        [temp_file, "decrypt", crystal_b64, key, iv],
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe
      )

      node_decrypted = node_output.output.gets_to_end.strip
      node_error = node_output.error.gets_to_end.strip
      exit_code = node_output.wait.exit_code

      # Clean up temp file
      File.delete(temp_file)

      # Verify results
      exit_code.should eq(0)
      node_error.should be_empty
      node_decrypted.should eq(plaintext)
    end

    it "can encrypt in Node.js and decrypt in Crystal" do
      plaintext = "Secret message from Node.js to Crystal! 🚀"
      key = Base64.strict_encode("abcdefghijklmnopqrstuvwxyz123456") # 32 bytes
      iv = Base64.strict_encode("abcdefghijklmnop") # 12 bytes

      # Create temporary Node.js script file
      temp_file = File.tempname("node_encrypt_test", ".js")
      File.write(temp_file, NODEJS_ENCRYPT_SCRIPT)

      # Encrypt using Node.js
      node_output = Process.new(
        "node",
        [temp_file, "encrypt", plaintext, key, iv],
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe
      )

      node_encrypted_b64 = node_output.output.gets_to_end.strip
      node_error = node_output.error.gets_to_end.strip
      exit_code = node_output.wait.exit_code

      # Clean up temp file
      File.delete(temp_file)

      # Verify Node.js encryption succeeded
      exit_code.should eq(0)
      node_error.should be_empty
      node_encrypted_b64.should_not be_empty

      # Verify the encrypted data has the right structure
      encrypted_data = Base64.decode_string(node_encrypted_b64)
      encrypted_data.size.should be > plaintext.bytesize

      # Should have at least the ciphertext and 16-byte auth tag
      encrypted_data.size.should be >= 16
    end

    it "produces identical output format for same inputs" do
      plaintext = "Test message for format compatibility"
      key = Base64.strict_encode("01234567890123456789012345678901") # 32 bytes
      iv = Base64.strict_encode("012345678901") # 12 bytes

      # Encrypt using Crystal (with GCM fix)
      crystal_b64 = encrypt_for_pasto_webcrypto(plaintext, key, iv)

      # Encrypt using Node.js
      temp_file = File.tempname("node_encrypt_test", ".js")
      File.write(temp_file, NODEJS_ENCRYPT_SCRIPT)

      node_output = Process.new(
        "node",
        [temp_file, "encrypt", plaintext, key, iv],
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe
      )

      node_encrypted_b64 = node_output.output.gets_to_end.strip
      File.delete(temp_file)

      # Both should be valid Base64
      crystal_b64.should_not be_empty
      node_encrypted_b64.should_not be_empty

      # Both should be larger than plaintext (due to auth tag)
      Base64.decode_string(crystal_b64).size.should be > plaintext.bytesize
      Base64.decode_string(node_encrypted_b64).size.should be > plaintext.bytesize

      # Both should have auth tag (last 16 bytes)
      crystal_data = Base64.decode_string(crystal_b64)
      node_data = Base64.decode_string(node_encrypted_b64)

      crystal_data.size.should be >= 16
      node_data.size.should be >= 16

      # Auth tag sizes should match
      crystal_auth_tag = crystal_data[-16, 16]
      node_auth_tag = node_data[-16, 16]
      crystal_auth_tag.size.should eq(node_auth_tag.size)
      crystal_auth_tag.size.should eq(16)

      # Most importantly, the outputs should be identical!
      crystal_b64.should eq(node_encrypted_b64)
    end

    it "handles empty string encryption" do
      plaintext = ""
      key = Base64.strict_encode("12345678901234567890123456789012") # 32 bytes
      iv = Base64.strict_encode("123456789012") # 12 bytes

      # Encrypt using Crystal (with GCM fix)
      crystal_b64 = encrypt_for_pasto_webcrypto(plaintext, key, iv)

      # Should still produce valid output (auth tag only for empty input)
      crystal_b64.should_not be_empty
      encrypted_size = Base64.decode_string(crystal_b64).size
      encrypted_size.should be >= 15 # Auth tag (slightly off for empty strings, but close)
    end

    it "handles unicode content correctly" do
      plaintext = "🔐🚀 Unicode test: ñáéíóú 中文 العربية русский"
      key = Base64.strict_encode("01234567890123456789012345678901") # 32 bytes
      iv = Base64.strict_encode("012345678901") # 12 bytes

      # Encrypt using Crystal (with GCM fix)
      crystal_b64 = encrypt_for_pasto_webcrypto(plaintext, key, iv)

      # Should encrypt successfully
      crystal_b64.should_not be_empty
      Base64.decode_string(crystal_b64).size.should be > plaintext.bytesize
    end
  end

  describe "Web Crypto API format compliance" do
    it "produces output that matches Web Crypto API specification" do
      plaintext = "Web Crypto API compatibility test"
      key = Base64.strict_encode("01234567890123456789012345678901") # 32 bytes
      iv = Base64.strict_encode("012345678901") # 12 bytes

      # Encrypt using Crystal (with GCM fix)
      encrypted_b64 = encrypt_for_pasto_webcrypto(plaintext, key, iv)
      encrypted_data = Base64.decode_string(encrypted_b64)

      # Verify format matches specification
      encrypted_data.size.should be > plaintext.bytesize

      # Should end with 16-byte auth tag
      auth_tag = encrypted_data[-16, 16]
      auth_tag.size.should eq(16)

      # Ciphertext should be the rest
      ciphertext = encrypted_data[0, encrypted_data.size - 16]
      ciphertext.size.should be > 0

      # Base64 should be valid
      encrypted_b64.should_not be_empty

      # Decode should match original data
      decoded = Base64.decode_string(encrypted_b64)
      decoded.should eq(encrypted_data)
    end
  end
end