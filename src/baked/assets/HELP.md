# Pasto Help & Usage Guide

Welcome to Pasto, a modern pastebin with advanced features for code sharing, syntax highlighting, and secure access. This guide covers the essentials to help you get started.

## Creating a Paste
To create a new paste, simply visit the main page and enter your code or text in the editor. Optionally, set a title and select the programming language for accurate syntax highlighting. Click "Create Paste" to save and share your snippet.

## Syntax Highlighting & Themes
Pasto automatically detects the language of your paste or lets you choose one manually. You can also select from a wide range of syntax highlighting themes for both light and dark modes, making code easy to read and present.

## Markdown Support
If your paste is Markdown, Pasto provides a live preview and lets you toggle between source and rendered views. This is perfect for sharing formatted documentation, notes, or README files.

## Editing & Ownership
If you are logged in, your pastes are associated with your account and can be edited later. Anonymous users can create pastes, but these cannot be edited or deleted after creation. Log in to unlock full control over your content.

## User Accounts & SSH Integration
Pasto supports user accounts and SSH key authentication. Link your SSH key in your profile to enable secure, command-line paste creation and management.

## Creating Pastes via SSH
You can create encrypted pastes directly from your terminal using SSH. No authentication required - just use your SSH key:

```bash
# Basic encrypted paste (auto-generates key)
echo "Secret data" | ssh -p 2222 pasto.example.com paste --encrypted

# With additional options
cat sensitive.conf | ssh -p 2222 pasto.example.com paste --encrypted -t "Config" -f sensitive.conf

# List your pastes
ssh -p 2222 pasto.example.com list

# SSH help for all commands
ssh -p 2222 pasto.example.com help
```

SSH pastes support encrypted content with the same AES-256-GCM security as the web interface. The server generates a secure encryption key and returns it to you for safe sharing.

## Rate Limiting & Abuse Prevention
To ensure fair use, Pasto enforces rate limits on paste creation and other actions. If you hit a limit, wait a few minutes before trying again. Logged-in users enjoy higher limits.

## Privacy & Security
Pastes are private by default (only accessible via their unique URL). You can share the link with anyone you trust. For sensitive data, consider using the SSH interface for added security.

## 🔐 Encryption & Zero-Knowledge Security

Pasto supports **end-to-end encryption** using AES-256-GCM, ensuring zero-knowledge security where the server cannot decrypt your content. Your data is encrypted in your browser before being sent to the server.

### **Encryption Features**
- **Client-side encryption**: Data is encrypted in your browser using Web Crypto API
- **Zero-knowledge**: The server stores only encrypted blobs it cannot read
- **AES-256-GCM**: Industry-standard symmetric encryption with authentication
- **Key management**: Auto-generated keys or password-based encryption
- **Cross-platform**: Web UI, SSH, and OpenSSL CLI compatibility

### **Web Interface Encryption**

#### **Creating Encrypted Pastes**
1. Click the 🔒 **lock button** in the web interface
2. Choose your encryption method:
   - **Auto-generate key** (recommended): Creates a cryptographically secure random key
   - **Use password**: Provide your own password for memorable encryption
3. Create your paste as normal
4. **Important**: Save the provided key/password - it cannot be recovered!

#### **Encryption Options**
- **Key-based encryption**: 32-byte random key + 12-byte IV
- **Password-based encryption**: PBKDF2 key derivation (100,000 iterations)
- **Auto-generated keys**: Maximum security with no password to remember
- **Session storage**: Keys are temporarily stored for easy decryption

#### **Viewing Encrypted Pastes**
- **Automatic decryption**: If you have the key in session storage
- **Manual entry**: Enter the key or password when prompted
- **Secure display**: Content decrypts only in your browser

### **SSH Encryption**

Create encrypted pastes directly from your terminal with automatic key generation:

```bash
# Basic encrypted paste (server generates key)
echo "Secret data" | ssh -p 2222 pasto.example.com paste --encrypted
# Output: URL + 🔒 Encryption key: [base64-key]

# With title and filename
cat sensitive.conf | ssh -p 2222 pasto.example.com paste --encrypted -t "Production Config" -f production.yaml

# List your encrypted pastes
ssh -p 2222 pasto.example.com list

# SSH help
ssh -p 2222 pasto.example.com help
```

#### **Zero-Trust Pre-Encryption**
For maximum security, encrypt before sending to the server:

```bash
# Encrypt client-side first (true zero-trust)
ENCRYPTED=$(echo "Highly secret data" | node -e "
const crypto = require('crypto');
const key = crypto.randomBytes(32);
const iv = crypto.randomBytes(12);
const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
let data = '';
process.stdin.on('data', chunk => data += chunk);
process.stdin.on('end', () => {
  const encrypted = Buffer.concat([cipher.update(data, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  console.log(Buffer.concat([encrypted, authTag]).toString('base64'));
});")

# Send pre-encrypted data with IV
echo "$ENCRYPTED" | ssh -p 2222 pasto.example.com paste --pre-encrypted --iv "$IV_BASE64"
```

### **Security Environment Requirements**

For security reasons, encrypted pastes require a **secure web environment**:

- **HTTPS**: Required in production environments
- **Secure localhost**: Use `127.0.0.1` instead of `0.0.0.0` for development
- **Modern browsers**: Web Crypto API support required
- **No mixed content**: All resources must be served securely

If accessed in an insecure environment, users will see a clear error message with guidance on how to fix the issue.

### **API & Access**

Encrypted pastes support standard features:
- **Download**: Encrypted content downloads with metadata
- **Version history**: Maintained for encrypted pastes
- **Copy to clipboard**: After successful decryption

### **Encryption Security Model**

#### **Zero-Knowledge Architecture**
- **Client-side encryption**: Data never leaves your browser unencrypted
- **Server storage**: Only stores encrypted blobs + metadata
- **No backdoors**: Impossible for server to decrypt your content
- **Key isolation**: Encryption keys are never transmitted to server

#### **Cryptographic Details**
- **Algorithm**: AES-256-GCM (Galois/Counter Mode)
- **Key generation**: Cryptographically secure random numbers
- **Authentication**: GCM provides integrity verification
- **Password hashing**: PBKDF2 with 100,000 iterations (for password-based)

#### **Security Best Practices**
- **Auto-generated keys**: Most secure option
- **Strong passwords**: If using password-based encryption
- **Secure key sharing**: Share keys only through secure channels
- **Single use**: Consider each paste's sensitivity level

### OpenSSL CLI Compatibility

Encrypt data from your command line and decrypt it in the web interface (or vice versa) using these OpenSSL commands:

#### **Method 1: Key-based Encryption**

```bash
# Generate encryption keys
KEY=$(openssl rand -hex 32)                    # 32-byte key (hex)
IV=$(openssl rand -hex 12)                     # 12-byte IV (hex)

# Encrypt your data
ENCRYPTED=$(echo "Your secret message" | openssl enc -aes-256-gcm -K $KEY -iv $IV | base64)

# Convert keys to base64 for web UI
KEY_B64=$(echo -n $KEY | xxd -r -p | base64)
IV_B64=$(echo -n $IV | xxd -r -p | base64)

echo "Encrypted: $ENCRYPTED"
echo "Web UI Key: $KEY_B64"
echo "Web UI IV: $IV_B64"

# Decrypt with OpenSSL
echo "$ENCRYPTED" | base64 -d | openssl enc -aes-256-gcm -d -K $KEY -iv $IV
```

#### **Method 2: Password-based Encryption**

```bash
# Generate salt and IV
SALT=$(openssl rand -hex 16)                   # 16-byte salt (hex)
IV=$(openssl rand -hex 12)                     # 12-byte IV (hex)

# Encrypt with password (PBKDF2, 100,000 iterations)
ENCRYPTED=$(echo "Secret data" | openssl enc -aes-256-gcm -S $SALT -iv $IV -pbkdf2 -iter 100000 -k "your_password" | base64)

# Convert to base64 for web UI
SALT_B64=$(echo -n $SALT | xxd -r -p | base64)
IV_B64=$(echo -n $IV | xxd -r -p | base64)

echo "Encrypted: $ENCRYPTED"
echo "Web UI Salt: $SALT_B64"
echo "Web UI IV: $IV_B64"

# Decrypt with password
echo "$ENCRYPTED" | base64 -d | openssl enc -aes-256-gcm -d -S $SALT -iv $IV -pbkdf2 -iter 100000 -k "your_password"
```

#### **SSH Encryption**

Create encrypted pastes via SSH with the `--encrypted` flag:

```bash
# Create encrypted paste (auto-generates key)
echo "Sensitive data" | ssh -p 2222 pasto.example.com paste --encrypted

# The output includes the encryption key for sharing
```

### 🎯 **Practical Use Cases & Workflows**

#### **Secure Code Sharing**
```bash
# Share proprietary code with a client
echo "function secretAlgorithm() { /* confidential */ }" | ssh -p 2222 pasto.example.com paste --encrypted -t "Secret Algorithm"
# Share the encryption key through a secure channel (Signal, encrypted email, etc.)
```

#### **Configuration Management**
```bash
# Encrypt production configs for team sharing
cat production.yaml | ssh -p 2222 pasto.example.com paste --encrypted -t "Production Config"
# Only team members with the key can access the configuration
```

#### **Password & Credential Sharing**
```bash
# Share temporary credentials securely
echo "Database connection: user=admin;password=secret123" | ssh -p 2222 pasto.example.com paste --encrypted
# Send key via separate secure communication channel
```

#### **Personal Knowledge Base**
```bash
# Encrypt personal notes and documents
cat journal-entry.md | ssh -p 2222 pasto.example.com paste --encrypted -t "Private Journal"
# Only you can decrypt with your stored key
```

#### **Incident Response**
```bash
# Share security logs with analysts
cat security-incident.log | ssh -p 2222 pasto.example.com paste --encrypted -t "Security Incident Logs"
# Provide key only to authorized security team
```

### 🔄 **Cross-Platform Workflows**

#### **Web → CLI → Web**
1. Create encrypted paste in web interface
2. Save the provided encryption key
3. Share with colleague who prefers CLI
4. They can decrypt using OpenSSL commands or view in web

#### **CLI → Web → Mobile**
1. Create encrypted paste via SSH from terminal
2. Share link and key with mobile user
3. They can view and decrypt on mobile web interface
4. Works seamlessly across all platforms

#### **Batch Encryption**
```bash
# Encrypt multiple files with the same key
KEY="your-secure-key-here"
for file in *.conf; do
  echo "Encrypting $file..."
  cat "$file" | openssl enc -aes-256-gcm -K $KEY -iv $(openssl rand -hex 12) | base64 | ssh -p 2222 pasto.example.com paste --encrypted -t "$file"
done
```

### 🔑 **Key Management Best Practices**

#### **Key Storage**
- **Auto-generated keys**: Most secure, no need to remember anything
- **Password managers**: Store encryption passwords securely
- **Physical security**: Write down keys and store in safe locations
- **Digital security**: Use encrypted password managers for key storage

#### **Key Sharing**
- **Separate channels**: Always share keys through different channels than content
- **Secure messaging**: Use Signal, WhatsApp, or encrypted email for keys
- **In-person**: For highly sensitive data, share keys face-to-face
- **Multi-factor**: Consider combining multiple key sharing methods

#### **Key Lifecycle**
- **One-time use**: Generate new keys for each sensitive paste
- **Time-limited**: Consider the sensitivity duration when choosing key management
- **Revocation**: Remember that encrypted pastes cannot be "un-shared"
- **Backup**: Securely backup important keys you might need later

### ⚠️ **Important Limitations**

#### **Security Considerations**
- **No key recovery**: Lost keys mean lost data forever
- **No revocation**: Once shared, encrypted pastes cannot be unshared
- **No server-side scanning**: Encrypted content cannot be scanned for malware
- **No search encryption**: Encrypted content is not searchable

#### **Feature Limitations**
- **No editing**: Encrypted pastes cannot be edited after creation
- **No preview**: Syntax highlighting works after decryption only

This comprehensive encryption system ensures your data remains private and secure across all platforms and use cases! 🛡️

## 🔧 Self-Encryption with Repository Crypto

For users who want to encrypt data client-side before uploading, you can use the same cryptographic implementation as the web interface:

**Repository crypto.js**: [GitHub Repository - src/baked/assets/crypto.js](https://github.com/ralsina/pasto/blob/main/src/baked/assets/crypto.js)

This file contains the `PastoCrypto` class used by the web interface for:
- **AES-256-GCM encryption** with Web Crypto API
- **Base64 encoding/decoding** utilities
- **Password-based key derivation** (PBKDF2)
- **Cross-platform compatibility**

#### **Self-Encryption Example**

```javascript
// Use the same crypto as the web interface
const { PastoCrypto } = require('./src/baked/assets/crypto.js');

// Encrypt data
const plaintext = "Secret information";
const encryptedB64 = PastoCrypto.encrypt(plaintext);
const ivB64 = PastoCrypto.generateRandomBytes(12);
const keyB64 = PastoCrypto.generateRandomBytes(32);

// Store encryptedB64, ivB64, and keyB64
// Then upload via SSH with --pre-encrypted --iv flags
```

## 📚 Complete Encryption Documentation

For detailed technical specifications, code examples, and implementation guides, see:

**[ENCRYPTION.md](/ENCRYPTION.md)** - Complete encryption format specification with:
- Technical algorithm details (AES-256-GCM)
- Implementation examples in Node.js, Python, Crystal
- Web Crypto API compatibility
- Security best practices
- Troubleshooting guide

## Advanced Features
- Download pastes with proper file extensions
- Copy to clipboard with one click
- View and restore previous versions (if enabled)
- Switch between light/dark UI and syntax themes

For more details, visit the project repository or contact the maintainer. Happy pasting!
