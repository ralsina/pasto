# Pasto Encryption Format Specification

This document provides the complete specification for encrypting data that can be decrypted by Pasto's web interface using Web Crypto API.

## Overview

Pasto supports two encryption workflows:

1. **Server-side encryption** (`--encrypted` flag): Server encrypts and returns the key
2. **Pre-encrypted zero-trust** (`--pre-encrypted --iv` flag): User encrypts data locally

Both workflows produce compatible encrypted data that can be decrypted in the browser.

## Technical Specification

### Algorithm
- **Cipher**: AES-256-GCM (Advanced Encryption Standard with Galois/Counter Mode)
- **Key size**: 32 bytes (256 bits)
- **IV/Nonce size**: 12 bytes (96 bits)
- **Authentication tag**: 16 bytes (128 bits)
- **Output format**: Base64-encoded `[ciphertext][16-byte auth tag]`

### Data Format

The encrypted data follows this exact format:

```
[ciphertext][16-byte authentication tag]
```

- **Ciphertext**: The encrypted plaintext
- **Authentication tag**: GCM authentication tag (last 16 bytes)
- **Total format**: Concatenated, then base64-encoded

This format is **identical** to Web Crypto API's AES-GCM output format.

## Implementation Examples

### Node.js (Recommended)

```javascript
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

// Example usage
const plaintext = "Secret data";
const key = crypto.randomBytes(32).toString('base64');  // Save this!
const iv = crypto.randomBytes(12).toString('base64');    // Share with paste

const encrypted = encryptForPasto(plaintext, key, iv);
console.log('Encrypted:', encrypted);
console.log('Key:', key);
console.log('IV:', iv);
```

### Python (PyCryptodome)

```python
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
import base64

def encrypt_for_pasto(plaintext, key_b64, iv_b64):
    key = base64.b64decode(key_b64)
    iv = base64.b64decode(iv_b64)

    cipher = AES.new(key, AES.MODE_GCM, nonce=iv)
    ciphertext, auth_tag = cipher.encrypt_and_digest(plaintext.encode())

    # Combine and encode (Web Crypto API compatible)
    result = ciphertext + auth_tag
    return base64.b64encode(result).decode()

# Example usage
plaintext = "Secret data"
key = base64.b64encode(get_random_bytes(32)).decode()  # Save this!
iv = base64.b64encode(get_random_bytes(12)).decode()    # Share with paste

encrypted = encrypt_for_pasto(plaintext, key, iv)
print(f"Encrypted: {encrypted}")
print(f"Key: {key}")
print(f"IV: {iv}")
```

### Crystal (AES-256-GCM)

```crystal
require "openssl"
require "base64"

def encrypt_for_pasto(plaintext, key_b64, iv_b64)
  key = Base64.decode_string(key_b64)
  iv = Base64.decode_string(iv_b64)

  cipher = OpenSSL::Cipher.new("aes-256-gcm")
  cipher.encrypt
  cipher.key = key
  cipher.iv = iv

  encrypted = cipher.update(plaintext) + cipher.final
  auth_tag = cipher.auth_tag

  # Combine and encode (Web Crypto API compatible)
  result = encrypted + auth_tag
  Base64.strict_encode(result)
end

# Example usage
plaintext = "Secret data"
key = Base64.strict_encode(Random::Secure.random_bytes(32))  # Save this!
iv = Base64.strict_encode(Random::Secure.random_bytes(12))    # Share with paste

encrypted = encrypt_for_pasto(plaintext, key, iv)
puts "Encrypted: #{encrypted}"
puts "Key: #{key}"
puts "IV: #{iv}"
```

## SSH Usage Examples

### Server-side Encryption (Convenience)

```bash
# Server encrypts and provides key
echo "Secret data" | ssh -p 2222 pasto.example.com paste --encrypted

# Output:
# https://pasto.example.com/abc123
# 🔒 Encryption key: abc123def456...
# ⚠️  Save this key securely - it cannot be recovered!
# 📋 To decrypt: Open the URL above and enter this key
```

### Pre-encrypted Zero-trust (Maximum Security)

```bash
# 1. Encrypt locally using Node.js
ENCRYPTED=$(echo "Secret data" | node encrypt.js --iv-base64 $(node -e "console.log(require('crypto').randomBytes(12).toString('base64'))"))

# 2. Extract IV from encrypt.js output (or generate your own)
IV="Vu6OfTLMuT4+wnqS"

# 3. Send pre-encrypted data to server
echo "$ENCRYPTED" | ssh -p 2222 pasto.example.com paste --iv "$IV"

# Output:
# https://pasto.example.com/def456
# 🔐 Zero-trust encrypted paste created
# 📋 To decrypt: Open the URL above and enter your encryption key
# 🔒 IV stored with paste: Vu6OfTLMuT4+wnqS
```

## Web Crypto API Compatibility

The encrypted format is designed to work directly with browser Web Crypto API:

```javascript
// Decrypt in browser
async function decryptPastoContent(encryptedB64, ivB64, keyB64) {
  const encrypted = Uint8Array.from(atob(encryptedB64), c => c.charCodeAt(0));
  const iv = Uint8Array.from(atob(ivB64), c => c.charCodeAt(0));
  const key = Uint8Array.from(atob(keyB64), c => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key,
    { name: 'AES-GCM' },
    false,
    ['decrypt']
  );

  const decrypted = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: iv },
    cryptoKey,
    encrypted
  );

  return new TextDecoder().decode(decrypted);
}
```

## Security Considerations

### Key Management
- **Never reuse keys** with the same IV
- **Generate new keys** for each sensitive paste
- **Share keys securely** through different channels than the paste URL
- **Consider key backup** for important data you might need later

### IV Management
- **IV is not secret** and can be stored/transmitted with encrypted data
- **Never reuse IV** with the same key
- **Generate fresh IV** for each encryption
- **12-byte IV** is standard for AES-256-GCM

### Best Practices
1. **Use random keys**: Never derive keys from predictable sources
2. **Secure channels**: Share keys through secure messaging, not the same channel as the paste
3. **Key storage**: Use proper password managers for encryption keys
4. **Verification**: Always test encryption/decryption with sample data first

## Troubleshooting

### Common Errors

1. **"Decryption failed: Invalid key or corrupted data"**
   - Check that the key is exactly correct (no extra whitespace)
   - Ensure the IV matches what was used for encryption
   - Verify the encrypted data wasn't truncated

2. **"Invalid encryption key format"**
   - Key must be valid base64 string encoding 32 bytes
   - Check for line breaks or extra characters in the key

3. **Encryption produces different output**
   - This is normal! AES-GCM uses random padding/IV
   - As long as decryption works with the same key/IV, it's correct

### Verification

Test your implementation:

```javascript
// Node.js test
const { encrypt, decrypt } = require('./encrypt-test.js');
const test = "Hello, Pasto!";
const key = 'a'.repeat(32); // Test key
const iv = 'b'.repeat(12);  // Test IV

const encrypted = encrypt(test, key, iv);
const decrypted = decrypt(encrypted, key, iv);

console.log(decrypted === test ? '✅ Working correctly' : '❌ Failed');
```

## Format Summary

| Component | Size | Encoding | Notes |
|-----------|------|----------|-------|
| **Key** | 32 bytes | Base64 | Secret, shared separately |
| **IV** | 12 bytes | Base64 | Not secret, stored with paste |
| **Ciphertext** | Variable | - | Encrypted plaintext |
| **Auth Tag** | 16 bytes | - | GCM authentication tag |
| **Output** | Ciphertext + Tag | Base64 | Web Crypto API compatible |

This specification ensures complete interoperability between terminal encryption tools and Pasto's web interface decryption.