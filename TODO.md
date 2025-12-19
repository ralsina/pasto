# Pasto Feature Enhancement Roadmap

## Vision
Make Pasto the best pastebin application by combining developer-friendly workflows with zero-knowledge security features across both web and SSH interfaces.

## Phase 1: Zero-Knowledge Foundation (Critical) - ✅ MOSTLY COMPLETED

### 🏗️ Core Encryption System
- [x] **Browser Client-Side Encryption**
  - [x] Implement AES-256-GCM encryption using Web Crypto API
  - [x] Encryption key embedded in URL fragment or session
  - [x] Server stores only encrypted blob
  - [x] Add "Encrypt" toggle to paste creation interface
  - [x] Client-side decryption on paste view

- [ ] **CLI Compatible Encryption**
  - [ ] Research: Crystal OpenSSL compatibility vs native implementation
  - [ ] Create `pasto-crypto` tool for encryption/decryption
  - [ ] Support standard OpenSSL commands for maximum compatibility
  - [ ] Ensure CLI and browser encryption are cross-compatible

- [x] **SSH Server Zero-Knowledge Enhancement**
  - [x] Add `--encrypted` flag for paste creation
  - [x] Add `get <id>` command to retrieve encrypted blobs
  - [x] Modify server to handle encrypted data without decryption
  - [x] Add help documentation for encryption workflows
  - [x] **SSH Interface Improvements**
    - [x] Add `get <id>` command to retrieve raw paste content
    - [x] Add `view <id>` command to view paste content
    - [x] Add `info <id>` command to show paste metadata
    - [x] Add `edit <id>` command for pipe-based content editing
    - [x] Add `delete <id>` command to remove pastes
    - [x] Implement ownership verification for all operations
    - [x] Add comprehensive help documentation

### 🔐 Security Features
- [x] **Expiration Settings**
  - [x] Add time-based expiration (1h, 1d, 1w, 1m, never)
  - [x] Background cleanup task for expired pastes (handled via checks on access)
  - [x] SSH flag: `--expire=1h` `--expire=1d`
  - [x] UI controls for expiration selection

- [x] **View-Once/Burn After Reading**
  - [x] Delete paste after first successful access
  - [x] Access tracking and immediate cleanup
  - [x] Works with both encrypted and regular pastes
  - [x] Visual indicator for view-once pastes

- [x] **Password Protection**
  - [x] Server-side AES-256 encryption for password-protected pastes
  - [x] Password prompt overlay before content display
  - [x] Add optional password field to paste creation
  - [x] SSH integration: `--password=secret`

### 📱 User Experience Enhancements
- [x] **QR Code Generation**
  - [x] Generate QR codes for paste URLs
  - [x] Include encryption keys in QR codes for encrypted pastes (User concern via URL)
  - [x] Crystal QR code library integration
  - [x] Mobile-friendly sharing feature

- [x] **Raw View Endpoint**
  - [x] Add `/raw/{id}` endpoint for plain text access
  - [x] Essential for curl/wget workflows
  - [x] Support for encrypted raw access (returns encrypted blob)

## Phase 2: Enhanced Privacy & Features (High Value)

### 🔒 Privacy Controls
- [x] **Enhanced Privacy Levels**
  - [x] **Public**: Accessible via URL only (privacy-by-design)
  - [x] **Private**: Owner-only, requires login
  - [x] **Encrypted variants** of privacy levels
  - [x] User-based access control system

- [ ] **Custom Paste URLs**
  - [ ] Allow custom paste IDs: `/my-custom-paste`
  - [ ] Collision detection and validation
  - [ ] Enhanced sharing and branding
  - [ ] Integration with encryption for custom secure URLs

### 📎 Advanced Features
- [ ] **File Attachment Support**
  - [ ] Allow small file attachments with pastes
  - [ ] File storage alongside paste data
  - [ ] Size limits and file type validation
  - [ ] Encrypted file attachments support

- [ ] **Enhanced API**
  - [ ] RESTful API for all features
  - [ ] API key authentication for users
  - [ ] Programmatic access to encryption features
  - [ ] Rate limiting and abuse prevention

## Phase 3: Premium Differentiators (Market Leadership)

### 🌟 Unique Features
- [x] **Live Preview for Encrypted Content**
  - [x] Real-time syntax highlighting for encrypted pastes
  - [x] Client-side decryption + highlighting
  - [x] Maintain 321+ theme support for encrypted content

- [ ] **Advanced Collaboration**
  - [ ] Encrypted comment/annotation system
  - [ ] Secure paste sharing with multiple recipients
  - [ ] Version history for encrypted pastes
  - [ ] Access logs and analytics for paste owners

### 🚀 Performance & Scalability
- [ ] **Optimization**
  - [ ] Sub-100ms encryption/decryption performance
  - [ ] Efficient background cleanup processes
  - [ ] Memory usage optimization for large encrypted pastes
  - [ ] CDN integration for static assets

- [ ] **Monitoring & Analytics**
  - [ ] Usage metrics and dashboards
  - [ ] Performance monitoring
  - [ ] Security event logging
  - [ ] User behavior analytics

## Technical Implementation Details

### Database Model Extensions ✅ IMPLEMENTED
```crystal
class Paste
  # ✅ Implemented fields...
  property expires_at : Time?
  property password_hash : String?
  property? private : Bool = false  # Simplified: URL-only access vs owner-only
  property burn_after_reading : Bool = false

  # ✅ Encryption fields
  property encrypted_content : String?
  property? is_encrypted : Bool = false
  property encryption_iv : String?
  property encryption_tag : String?

  # ❌ Not implemented fields
  # property attachment_path : String?
  # property custom_id : String?
end
```

### New CLI Tools
- [ ] `pasto-crypto` - Standalone encryption/decryption tool
- [ ] `pasto-ssh` - Enhanced SSH client with encryption support
- [ ] Integration with existing `pasto-ssh` binary

### New HTTP Endpoints ✅ MOSTLY IMPLEMENTED
```
✅ GET  /{id}#key            # Decrypt in browser (client-side)
✅ GET  /raw/{id}            # Get raw content (including encrypted)
✅ GET  /qr/{id}             # QR code image with encryption key
✅ POST /{id}                # Standard paste creation
✅ POST /{id}/delete         # Delete paste (owner only)
❌ POST /api/encrypt         # Dedicated API endpoint
❌ POST /{id}/decrypt        # Client-side decryption helper
✅ POST /{id}/access         # Track view-once access (handled internally)
```

### New SSH Commands ✅ PARTIALLY IMPLEMENTED
```bash
# ✅ Encryption workflows
cat file.txt | ssh -p 2222 pasto.com --encrypted
ssh -p 2222 pasto.com --encrypted --expire=1h < file.txt

# ✅ Basic paste creation
echo "Hello World" | ssh -p 2222 pasto.com
ssh -p 2222 pasto.com paste < file.txt

# ✅ Help and documentation
ssh -p 2222 pasto.com help

# ✅ Implemented SSH viewing and management commands
ssh -p 2222 pasto.com get <paste_id>      # Retrieve paste content
ssh -p 2222 pasto.com view <paste_id>     # View paste content
ssh -p 2222 pasto.com info <paste_id>     # Show paste metadata
ssh -p 2222 pasto.com delete <paste_id>   # Delete a paste
cat new.txt | ssh -p 2222 pasto.com edit <paste_id>  # Edit paste

# ❌ Not yet implemented
# ssh -p 2222 pasto.com help encryption
# ssh -p 2222 pasto.com help security
```

## High Priority Fixes

### SSH Server Issues
- [ ] **CRITICAL**: Implement auto-restart mechanism for SSH process when it crashes
- [ ] Investigate Shirk 0.1.2 stability compared to 0.1.0
- [ ] Add error logging for SSH process crashes

### Cross-Process Coordination
- [ ] Test SSH login → HTTP token validation flow
- [ ] Test concurrent paste creation (SSH + HTTP simultaneously)

## Dependencies & Research Tasks

### Research Required
- [ ] Crystal OpenSSL vs native encryption implementation (currently using GCM fix monkeypatch)
- [ ] Cross-platform CLI tool distribution strategy

### Dependencies to Add
- [ ] AES encryption library (Crystal compatible)
- [ ] Background task scheduler
- [ ] Enhanced logging and monitoring

---

**Last Updated**: 2025-12-19
**Next Review**: After Phase 2 start
