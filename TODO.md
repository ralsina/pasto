# Pasto Feature Enhancement Roadmap

## Vision
Make Pasto the best pastebin application by combining developer-friendly workflows with zero-knowledge security features across both web and SSH interfaces.

## Phase 1: Zero-Knowledge Foundation (Critical)

### 🏗️ Core Encryption System
- [ ] **Browser Client-Side Encryption**
  - [ ] Implement AES-256-GCM encryption using Web Crypto API
  - [ ] Encryption key embedded in URL fragment (`#key=`)
  - [ ] Server stores only encrypted blob
  - [ ] Add "Encrypt" toggle to paste creation interface
  - [ ] Client-side decryption on paste view

- [ ] **CLI Compatible Encryption**
  - [ ] Research: Crystal OpenSSL compatibility vs native implementation
  - [ ] Create `pasto-crypto` tool for encryption/decryption
  - [ ] Support standard OpenSSL commands for maximum compatibility
  - [ ] Ensure CLI and browser encryption are cross-compatible

- [ ] **SSH Server Zero-Knowledge Enhancement**
  - [ ] Add `--encrypted` flag for paste creation
  - [ ] Add `get <id>` command to retrieve encrypted blobs
  - [ ] Modify server to handle encrypted data without decryption
  - [ ] Add help documentation for encryption workflows

### 🔐 Security Features
- [ ] **Expiration Settings**
  - [ ] Add time-based expiration (1h, 1d, 1w, 1m, never)
  - [ ] Background cleanup task for expired pastes
  - [ ] SSH flag: `--expire=1h` `--expire=1d`
  - [ ] UI controls for expiration selection

- [ ] **View-Once/Burn After Reading**
  - [ ] Delete paste after first successful access
  - [ ] Access tracking and immediate cleanup
  - [ ] Works with both encrypted and regular pastes
  - [ ] Visual indicator for view-once pastes

- [ ] **Password Protection**
  - [ ] Server-side AES-256 encryption for password-protected pastes
  - [ ] Password prompt overlay before content display
  - [ ] Add optional password field to paste creation
  - [ ] SSH integration: `--password=secret`

### 📱 User Experience Enhancements
- [ ] **QR Code Generation**
  - [ ] Generate QR codes for paste URLs
  - [ ] Include encryption keys in QR codes for encrypted pastes
  - [ ] Crystal QR code library integration
  - [ ] Mobile-friendly sharing feature

- [ ] **Raw View Endpoint**
  - [ ] Add `/raw/{id}` endpoint for plain text access
  - [ ] Add `/raw/{id}/{password}` for password-protected raw access
  - [ ] Essential for curl/wget workflows
  - [ ] Support for encrypted raw access

## Phase 2: Enhanced Privacy & Features (High Value)

### 🔒 Privacy Controls
- [ ] **Enhanced Privacy Levels**
  - [ ] **Public**: Listed, searchable (current default)
  - [ ] **Unlisted**: Not listed, accessible via URL only
  - [ ] **Private**: Owner-only, requires login
  - [ ] **Encrypted variants** of each privacy level
  - [ ] Extend existing user system with visibility controls

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
- [ ] **Live Preview for Encrypted Content**
  - [ ] Real-time syntax highlighting for encrypted pastes
  - [ ] Client-side decryption + highlighting
  - [ ] Maintain 321+ theme support for encrypted content
  - [ ] Unique feature: no other encrypted pastebin has live preview

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

### Database Model Extensions
```crystal
class Paste
  # Existing fields...
  property expires_at : Time?
  property password_hash : String?
  property visibility : String # "public", "unlisted", "private"
  property view_count : Int32 = 0
  property burn_after_reading : Bool = false
  property attachment_path : String?
  property custom_id : String?

  # Encryption fields
  property encrypted_content : String?
  property is_encrypted : Bool = false
  property encryption_iv : String?
  property encryption_tag : String?
end
```

### New CLI Tools
- [ ] `pasto-crypto` - Standalone encryption/decryption tool
- [ ] `pasto-ssh` - Enhanced SSH client with encryption support
- [ ] Integration with existing `pasto-ssh` binary

### New HTTP Endpoints
```
POST /api/encrypt          # Store encrypted blob
GET  /{id}#key            # Decrypt in browser
GET  /raw/{id}            # Get encrypted blob
POST /{id}/decrypt        # Client-side decryption
GET  /qr/{id}             # QR code image
POST /{id}/access         # Track view-once access
```

### New SSH Commands
```bash
# Encryption workflows
cat file.txt | ssh pasto.com --encrypted
ssh pasto.com --encrypted --expire=1h < file.txt

# Retrieve encrypted content
ssh pasto.com get <paste_id>

# Help and documentation
ssh pasto.com help encryption
ssh pasto.com help security
```

## Competitive Advantages After Implementation

| Feature | Pasto | YOPass | PrivateBin | Pastebin.com | Microbin |
|---------|-------|--------|------------|--------------|----------|
| SSH Access | ✅ | ❌ | ❌ | ❌ | ❌ |
| Zero-Knowledge Web | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Zero-Knowledge SSH** | ✅ (EXCLUSIVE) | ❌ | ❌ | ❌ | ❌ |
| CLI + Browser Compatible | ✅ (EXCLUSIVE) | ❌ | ❌ | ❌ | ❌ |
| Live Preview | ✅ | ❌ | ❌ | ❌ | ❌ |
| 321+ Themes | ✅ | ❌ | ✅ | ✅ (Pro) | ❌ |
| Version History | ✅ | ❌ | ❌ | ❌ | ❌ |
| QR Code + Key | ✅ | ❌ | ❌ | ❌ | ✅ |

## Success Metrics

### Security Metrics
- [ ] Zero successful plaintext leaks (by design)
- [ ] All sensitive data processed client-side
- [ ] Independent security audit passed

### Usage Metrics
- [ ] Encrypted vs unencrypted paste ratio > 30%
- [ ] SSH usage growth > 50%
- [ ] User adoption and retention rates
- [ ] Feature usage analytics

### Performance Metrics
- [ ] Sub-100ms encryption/decryption times
- [ ] <500ms paste creation times
- [ ] 99.9% uptime SLA
- [ ] Memory usage < 100MB for typical loads

## User Workflows to Support

### Security-Conscious Developer
```bash
# Quick secure paste with expiration
cat api-key.txt | pasto-crypto encrypt --pipe | ssh pasto.com --encrypted --expire=1h

# Retrieve on mobile via QR code
# Scan → Opens browser → Auto-decrypts client-side
```

### Team Collaboration
```bash
# Encrypt sensitive config for team
pasto-crypto encrypt production.yaml --team --expire=1d
# Outputs: URL + separate keys for each team member
```

### Web User Experience
1. Click "Encrypt" toggle
2. Paste sensitive data
3. Set expiration and privacy options
4. Share URL confidently (even Pasto can't read it)

## Marketing Positioning
**"Pasto: The only pastebin with zero-knowledge encryption for both web and SSH workflows"**

### Key Selling Points
- **Zero-Knowledge Everywhere**: Web, SSH, and CLI
- **Developer First**: Seamless terminal workflows
- **Privacy by Design**: Client-side encryption always
- **Feature Rich**: Live preview, themes, version history
- **Open Source**: Transparent and auditable

## Implementation Timeline

### Phase 1 (Weeks 1-3): Zero-Knowledge Foundation
- Week 1: Core encryption system (browser + CLI)
- Week 2: SSH server enhancements + basic security features
- Week 3: Expiration, view-once, QR codes

### Phase 2 (Weeks 4-5): Enhanced Privacy
- Week 4: Privacy controls + custom URLs
- Week 5: File attachments + API enhancements

### Phase 3 (Weeks 6-8): Premium Features
- Week 6-7: Advanced collaboration features
- Week 8: Performance optimization + monitoring

## Dependencies & Research Tasks

### Research Required
- [ ] Crystal OpenSSL vs native encryption implementation
- [ ] Cross-platform CLI tool distribution strategy
- [ ] Web Crypto API compatibility testing
- [ ] Performance benchmarking for encryption operations

### Dependencies to Add
- [ ] AES encryption library (Crystal compatible)
- [ ] QR code generation library
- [ ] Background task scheduler
- [ ] Enhanced logging and monitoring

---

**Last Updated**: $(date)
**Next Review**: After Phase 1 completion
**Owner**: Development Team