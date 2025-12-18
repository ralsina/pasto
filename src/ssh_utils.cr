require "openssl"
require "digest"
require "./logging"

module Pasto
  module SSHUtils
    # Extract SSH key fingerprint using OpenSSL
    def self.extract_fingerprint(public_key : String) : String
      # Use Crystal's OpenSSL bindings to extract fingerprint without external process

      # Normalize the key first
      normalized_key = normalize_key(public_key)
      parts = normalized_key.split(/\s+/)

      if parts.size < 2
        raise "Invalid SSH key format"
      end

      # Decode the base64 key data
      key_data = Base64.decode(parts[1])

      # Calculate SHA256 fingerprint using the same method ssh-keygen uses
      digest = Digest::SHA256.digest(key_data)

      # Convert to base64 and take first 43 characters (ssh-keygen style)
      fingerprint = Base64.strict_encode(digest)[0, 43]

      # Remove padding but KEEP standard base64 characters (+ and /)
      fingerprint = fingerprint.rstrip('=')

      "SHA256:#{fingerprint}"
    rescue ex
      raise "Failed to extract SSH key fingerprint: #{ex.message}"
    end

    # Check if a public key is already associated with any user
    def self.key_already_associated?(fingerprint : String) : Bool
      # Check all SSH keys to see if this fingerprint exists
      # This is inefficient with Sepia but necessary for security

      # We need to iterate through all SSHKey objects
      # This is a limitation of the current storage system
      data_dir = "data/Pasto::SSHKey"
      return false unless Dir.exists?(data_dir)

      Dir.each_child(data_dir) do |key_file|
        begin
          key_data = File.read(File.join(data_dir, key_file))
          # Parse the JSON to get the fingerprint
          parsed = JSON.parse(key_data)
          if parsed["fingerprint"]?.try(&.as_s) == fingerprint
            return true
          end
        rescue
          # Skip files that can't be parsed
          next
        end
      end

      false
    rescue
      false
    end

    # Normalize and clean SSH key string
    def self.normalize_key(public_key : String) : String
      # Remove leading/trailing whitespace
      cleaned = public_key.strip

      # Split into parts and filter out empty strings
      parts = cleaned.split(/\s+/).reject(&.empty?)

      # SSH keys should have at least 2 parts (type and key)
      # Optional third part is comment
      if parts.size < 2
        raise "Invalid SSH key format - expected at least key type and key data"
      end

      # Reconstruct the key without the comment (we don't need it)
      "#{parts[0]} #{parts[1]}"
    end

    # Check if SSH key looks reasonable before further processing
    def self.sanity_check_key(public_key : String) : Bool
      normalized = normalize_key(public_key)
      parts = normalized.split(/\s+/)

      # Basic format checks
      return false if parts.size < 2
      return false unless ["ssh-rsa", "ssh-dss", "ssh-ed25519", "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521", "sk-ssh-ed25519@openssh.com", "sk-ecdsa-sha2-nistp256@openssh.com"].includes?(parts[0])

      # The key data should be base64
      return false unless parts[1].matches?(/^[A-Za-z0-9+\/]+={0,2}$/)
      return false if parts[1].size < 30 # SSH keys are reasonably long

      true
    rescue
      false
    end

    # Extract fingerprint from SSH connection context
    # Note: This is a workaround since we don't have direct access to the public key
    # during SSH connection. We'll use the fingerprint passed by Shirk.
    def self.extract_fingerprint_from_pubkey(fingerprint : String) : String
      # Shirk passes us the fingerprint directly, so just return it
      Pasto::Logging.debug("SSH DEBUG: extract_fingerprint_from_pubkey called with: #{fingerprint}")
      fingerprint
    end
  end
end
