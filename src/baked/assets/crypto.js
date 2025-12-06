// Pasto Client-Side Encryption Module
// Provides AES-256-GCM encryption using Web Crypto API
// Compatible with OpenSSL for CLI workflows

class PastoCrypto {
  // Base64 encoding/decoding helpers
  static toBase64(bytes) {
    return btoa(String.fromCharCode.apply(null, bytes));
  }

  static fromBase64(base64) {
    return Uint8Array.from(atob(base64), c => c.charCodeAt(0));
  }

  // Generate cryptographically secure random bytes
  static generateRandomBytes(length) {
    return crypto.getRandomValues(new Uint8Array(length));
  }

  // Encrypt plaintext using AES-256-GCM
  static async encrypt(plaintext) {
    try {
      // Generate random 32-byte key and 12-byte IV
      const key = this.generateRandomBytes(32);
      const iv = this.generateRandomBytes(12);

      // Import key for encryption
      const cryptoKey = await crypto.subtle.importKey(
        'raw',
        key,
        { name: 'AES-GCM' },
        false,
        ['encrypt']
      );

      // Convert plaintext to bytes
      const plaintextBytes = new TextEncoder().encode(plaintext);

      // Encrypt using AES-256-GCM
      const encryptedArray = await crypto.subtle.encrypt(
        { name: 'AES-GCM', iv: iv },
        cryptoKey,
        plaintextBytes
      );

      const encrypted = new Uint8Array(encryptedArray);

      return {
        encrypted: this.toBase64(encrypted),
        iv: this.toBase64(iv),
        key: this.toBase64(key)
      };
    } catch (error) {
      console.error('Encryption error:', error);
      throw new Error('Failed to encrypt content');
    }
  }

  // Decrypt ciphertext using AES-256-GCM
  static async decrypt(encryptedBase64, ivBase64, keyBase64) {
    try {
      // Check if Web Crypto API is available
      if (!window.crypto || !window.crypto.subtle) {
        throw new Error('Web Crypto API is not available. This feature requires a secure context (HTTPS) or a modern browser.');
      }

      // Convert base64 strings to bytes
      const encrypted = this.fromBase64(encryptedBase64);
      const iv = this.fromBase64(ivBase64);
      const key = this.fromBase64(keyBase64);

      // Import key for decryption
      const cryptoKey = await crypto.subtle.importKey(
        'raw',
        key,
        { name: 'AES-GCM' },
        false,
        ['decrypt']
      );

      // Decrypt
      const decryptedArray = await crypto.subtle.decrypt(
        { name: 'AES-GCM', iv: iv },
        cryptoKey,
        encrypted
      );

      const decrypted = new Uint8Array(decryptedArray);

      return new TextDecoder().decode(decrypted);
    } catch (error) {
      console.error('Decryption error:', error);
      throw new Error('Failed to decrypt content. Invalid key or corrupted data.');
    }
  }

  // Check if content appears to be encrypted (heuristic)
  static isEncrypted(content) {
    // If content looks like base64 and is reasonably long, it might be encrypted
    try {
      const decoded = atob(content);
      return decoded.length > 20 && /^[A-Za-z0-9+/=]+$/.test(content);
    } catch {
      return false;
    }
  }

  // Store key securely in session storage (temporary, tab-specific)
  static storeKeyInSession(pasteId, key) {
    if (typeof window === 'undefined') return;

    try {
      sessionStorage.setItem(`pasto_key_${pasteId}`, key);
    } catch (e) {
      console.error('Failed to store encryption key:', e);
    }
  }

  // Retrieve key from session storage
  static getKeyFromSession(pasteId) {
    if (typeof window === 'undefined') return null;

    try {
      return sessionStorage.getItem(`pasto_key_${pasteId}`);
    } catch (e) {
      console.error('Failed to retrieve encryption key:', e);
      return null;
    }
  }

  // Remove key from session storage
  static removeKeyFromSession(pasteId) {
    if (typeof window === 'undefined') return;

    try {
      sessionStorage.removeItem(`pasto_key_${pasteId}`);
    } catch (e) {
      console.error('Failed to remove encryption key:', e);
    }
  }

  // Derive key from password using PBKDF2 (compatible with OpenSSL)
  static async deriveKeyFromPassword(password, salt, iterations = 100000) {
    try {
      // Encode password as UTF-8 bytes
      const passwordBytes = new TextEncoder().encode(password);

      // Import password as key
      const baseKey = await crypto.subtle.importKey(
        'raw',
        passwordBytes,
        { name: 'PBKDF2' },
        false,
        ['deriveBits', 'deriveKey']
      );

      // Derive 32-byte key using PBKDF2
      const derivedKey = await crypto.subtle.deriveKey(
        {
          name: 'PBKDF2',
          salt: salt,
          iterations: iterations,
          hash: 'SHA-256'
        },
        baseKey,
        { name: 'AES-GCM', length: 256 },
        true,
        ['encrypt', 'decrypt']
      );

      // Export the derived key
      const keyBytes = await crypto.subtle.exportKey('raw', derivedKey);
      return new Uint8Array(keyBytes);
    } catch (error) {
      console.error('Key derivation error:', error);
      throw new Error('Failed to derive key from password');
    }
  }

  // Encrypt using user-provided password
  static async encryptWithPassword(plaintext, password) {
    try {
      // Generate random salt and IV
      const salt = this.generateRandomBytes(16); // 16-byte salt for PBKDF2
      const iv = this.generateRandomBytes(12);   // 12-byte IV for AES-GCM

      // Derive key from password
      const key = await this.deriveKeyFromPassword(password, salt);

      // Import key for encryption
      const cryptoKey = await crypto.subtle.importKey(
        'raw',
        key,
        { name: 'AES-GCM' },
        false,
        ['encrypt']
      );

      // Convert plaintext to bytes
      const plaintextBytes = new TextEncoder().encode(plaintext);

      // Encrypt using AES-256-GCM
      const encryptedArray = await crypto.subtle.encrypt(
        { name: 'AES-GCM', iv: iv },
        cryptoKey,
        plaintextBytes
      );

      const encrypted = new Uint8Array(encryptedArray);

      return {
        encrypted: this.toBase64(encrypted),
        iv: this.toBase64(iv),
        salt: this.toBase64(salt),
        password: password, // Store password for session use
        iterations: 100000
      };
    } catch (error) {
      console.error('Password encryption error:', error);
      throw new Error('Failed to encrypt content with password');
    }
  }

  // Decrypt using user-provided password
  static async decryptWithPassword(encryptedBase64, ivBase64, saltBase64, password, iterations = 100000) {
    try {
      // Convert base64 strings to bytes
      const encrypted = this.fromBase64(encryptedBase64);
      const iv = this.fromBase64(ivBase64);
      const salt = this.fromBase64(saltBase64);

      // Derive key from password
      const key = await this.deriveKeyFromPassword(password, salt, iterations);

      // Import key for decryption
      const cryptoKey = await crypto.subtle.importKey(
        'raw',
        key,
        { name: 'AES-GCM' },
        false,
        ['decrypt']
      );

      // Decrypt
      const decryptedArray = await crypto.subtle.decrypt(
        { name: 'AES-GCM', iv: iv },
        cryptoKey,
        encrypted
      );

      const decrypted = new Uint8Array(decryptedArray);

      return new TextDecoder().decode(decrypted);
    } catch (error) {
      console.error('Password decryption error:', error);
      throw new Error('Failed to decrypt content. Invalid password or corrupted data.');
    }
  }

  // Generate OpenSSL-compatible CLI commands for the current encryption
  static generateOpenSSLCommands(content, iv, key) {
    const keyHex = Array.from(this.fromBase64(key))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    const ivHex = Array.from(this.fromBase64(iv))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    return {
      encrypt: `echo "${content.replace(/"/g, '\\"')}" | openssl enc -aes-256-gcm -K ${keyHex} -iv ${ivHex} | base64`,
      decrypt: `echo <encrypted_base64> | base64 -d | openssl enc -aes-256-gcm -d -K ${keyHex} -iv ${ivHex}`,
      key: keyHex,
      iv: ivHex
    };
  }

  // Generate OpenSSL-compatible CLI commands for password-based encryption
  static generateOpenSSLPasswordCommands(content, iv, salt, password, iterations = 100000) {
    const ivHex = Array.from(this.fromBase64(iv))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    const saltHex = Array.from(this.fromBase64(salt))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    return {
      encrypt: `echo "${content.replace(/"/g, '\\"')}" | openssl enc -aes-256-gcm -S ${saltHex} -iv ${ivHex} -pbkdf2 -iter ${iterations} -k "${password}" | base64`,
      decrypt: `echo <encrypted_base64> | base64 -d | openssl enc -aes-256-gcm -d -S ${saltHex} -iv ${ivHex} -pbkdf2 -iter ${iterations} -k "${password}"`,
      password: password,
      salt: saltHex,
      iv: ivHex,
      iterations: iterations
    };
  }

  // Validate key format (base64 string that decodes to 32 bytes)
  static validateKey(keyBase64) {
    try {
      const keyBytes = this.fromBase64(keyBase64);
      return keyBytes.length === 32;
    } catch {
      return false;
    }
  }

  // Validate IV format (base64 string that decodes to 12 bytes)
  static validateIV(ivBase64) {
    try {
      const ivBytes = this.fromBase64(ivBase64);
      return ivBytes.length === 12;
    } catch {
      return false;
    }
  }
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = PastoCrypto;
} else if (typeof window !== 'undefined') {
  window.PastoCrypto = PastoCrypto;
}