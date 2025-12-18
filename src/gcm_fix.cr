require "openssl"

# Low-level OpenSSL bindings for GCM auth tag support
# This provides missing functionality for Crystal's OpenSSL wrapper

lib LibCrypto
  # Missing GCM control constants
  EVP_CTRL_GCM_GET_TAG   = 0x10
  EVP_CTRL_GCM_SET_TAG   = 0x11

  # Missing function binding for cipher context control
  fun evp_cipher_ctx_ctrl = EVP_CIPHER_CTX_ctrl(ctx : Void*, type : Int32, arg : Int32, ptr : Void*) : Int32
end

# Add GCM support methods to existing OpenSSL::Cipher class
class OpenSSL::Cipher
  # Get the authentication tag for GCM mode
  def get_gcm_auth_tag : Bytes
    unless authenticated?
      raise OpenSSL::Error.new("Cipher does not support authenticated mode")
    end

    tag_size = 16
    tag_buffer = Bytes.new(tag_size)

    # Access the internal context through the @ctx instance variable
    # This is a bit of a hack, but necessary to work around Crystal's limitations
    ctx_ptr = @ctx

    # Get the auth tag using OpenSSL directly
    result = LibCrypto.evp_cipher_ctx_ctrl(ctx_ptr, LibCrypto::EVP_CTRL_GCM_GET_TAG, tag_size, tag_buffer)
    if result != 1
      raise OpenSSL::Error.new("Failed to get GCM authentication tag")
    end

    tag_buffer
  end

  # Encrypt and get complete output with auth tag (Web Crypto API compatible)
  def encrypt_and_get_tag(data : String) : Bytes
    ciphertext = self.update(data) + self.final

    if authenticated?
      auth_tag = get_gcm_auth_tag
      ciphertext + auth_tag
    else
      ciphertext
    end
  end

  # Set the authentication tag for GCM mode (for decryption)
  def set_gcm_auth_tag(tag : Bytes)
    unless authenticated?
      raise OpenSSL::Error.new("Cipher does not support authenticated mode")
    end

    if tag.size != 16
      raise ArgumentError.new("GCM authentication tag must be exactly 16 bytes")
    end

    ctx_ptr = @ctx
    tag_buffer = tag.to_unsafe

    result = LibCrypto.evp_cipher_ctx_ctrl(ctx_ptr, LibCrypto::EVP_CTRL_GCM_SET_TAG, tag.size, tag_buffer)
    if result != 1
      raise OpenSSL::Error.new("Failed to set GCM authentication tag")
    end
  end
end

# Simple encryption function that produces Web Crypto API compatible output
def encrypt_for_pasto_webcrypto(plaintext : String, key_b64 : String, iv_b64 : String) : String
  key = Base64.decode(key_b64)
  iv = Base64.decode(iv_b64)

  # Validate inputs
  raise ArgumentError.new("Invalid key size: expected 32 bytes, got #{key.size}") unless key.size == 32
  raise ArgumentError.new("Invalid IV size: expected 12 bytes, got #{iv.size}") unless iv.size == 12

  cipher = OpenSSL::Cipher.new("aes-256-gcm")
  cipher.encrypt
  cipher.key = key.to_slice
  cipher.iv = iv.to_slice

  # Get complete output with auth tag
  encrypted_data = cipher.encrypt_and_get_tag(plaintext)
  Base64.strict_encode(encrypted_data)
end