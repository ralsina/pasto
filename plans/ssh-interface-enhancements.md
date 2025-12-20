# SSH Interface Enhancement Plan

## Current State (Updated 2025-12-19)

The SSH interface is **FULLY IMPLEMENTED** with all planned commands. Built using the Shirk framework with public key authentication and comprehensive rate limiting.

### ✅ Implemented Commands

**Core Commands:**
- `paste` - Create pastes with full encryption, expiration, burn-after-reading support
- `list` - List all pastes owned by SSH key with previews
- `get` - Retrieve raw paste content (with ownership verification)
- `view` - View paste content (currently aliases to `get`, decryption TODO)
- `edit` - Update paste content via stdin (basic implementation)
- `delete` - Remove paste permanently (with ownership verification)
- `info` - Show detailed paste metadata
- `login` - Generate login tokens for web interface
- `api-key` - Manage API keys (create, list, revoke)
- `add-key` / `ssh-key` - SSH key management with challenge-response
- `help` - Comprehensive usage documentation

**Key Features:**
- Non-interactive stdin/stdout interface (no TTY required)
- Public key authentication via Shirk
- Comprehensive rate limiting (paste, login, connection, key operations)
- Ownership verification for all operations
- Support for encrypted pastes with server-side encryption
- Pre-encrypted paste support with Web Crypto API compatibility
- Expiration times (10m, 1h, 1d, 1w, 1M, view-once)
- Burn-after-reading support
- Private paste support
- Clean error messages to stderr

### Implementation Details

**File Structure:**
- `src/pasto_ssh.cr` - Entry point, configuration, server initialization
- `src/ssh_server.cr` - Command handlers, encryption, rate limiting (1068 lines)
- `src/models/ssh_key.cr` - SSH key model with paste relationships
- `src/models/ssh_key_challenge.cr` - Key addition challenge system
- `src/ssh_utils.cr` - SSH utility functions

**Rate Limiting:**
- Paste operations: 20/60s per key
- Login tokens: 3/600s per key
- Connections: 30/60s per key
- SSH key ops: 5/300s per key

**Security:**
- All operations verify SSH key ownership
- AES-256-GCM encryption with PBKDF2 key derivation (100k iterations)
- Web Crypto API compatible encryption format
- Challenge-response for SSH key addition
- Rate limiting on all operations

## ⚠️ Remaining Enhancements (TODO)

### 1. ❌ Enhanced `view` Command with Decryption
**Status:** ❌ TODO - Basic implementation exists (aliases to `get`)
**Need:** Add password-based decryption support

```bash
# Multiple password input methods
ssh pasto.example.com view abc123 --password "secret123"
PASSWORD="secret123" ssh pasto.example.com view abc123
echo "secret123" | ssh pasto.example.com view abc123 --password-stdin
```

**Implementation Notes:**
- Currently `view` just calls `handle_get()` (line 620)
- Need to add password parsing and decryption logic
- Reuse encryption utilities from `handle_paste`
- Support environment variable, flag, and stdin password input

### 2. ❌ Enhanced `edit` Command with Metadata Updates
**Status:** ❌ TODO - Basic content replacement implemented
**Need:** Add metadata update flags

```bash
# With metadata updates
echo "updated" | ssh pasto.example.com edit abc123 --lang python --title "Fixed version"

# Encrypted paste editing with re-encryption
cat new.txt | ssh pasto.example.com edit abc123 --password "old123" --new-password "new123"
```

**Implementation Notes:**
- Basic edit exists (line 565-612)
- Need to add docopt parsing for `--lang`, `--title`, `--filename` flags
- Add encrypted paste re-encryption support
- Currently only updates content, not metadata

### 3. ❌ `list` Command Filtering (Optional)
**Status:** ❌ TODO - Fully functional, optional enhancement only
**Future:** Add simple filtering if needed (nice-to-have)

```bash
ssh pasto.example.com list --language python
ssh pasto.example.com list --encrypted
ssh pasto.example.com list --last 10
```

**Implementation Notes:**
- Current implementation is clean and functional (line 472-500)
- Filtering would be nice-to-have but not critical
- Could add flags for language, encryption status, count limits


## Technical Implementation Status

### ✅ Completed Components

**Command Parser (src/ssh_server.cr:133-170):**
```crystal
server.on_exec do |ctx|
  case cmd
  when "paste"   then handle_paste(ctx, fingerprint, base_url, args)
  when "login"   then handle_login(ctx, fingerprint, base_url)
  when "list"    then handle_list(ctx, fingerprint, base_url)
  when "get"     then handle_get(ctx, fingerprint, args)
  when "delete"  then handle_delete(ctx, fingerprint, args)
  when "edit"    then handle_edit(ctx, fingerprint, args)
  when "view"    then handle_view(ctx, fingerprint, args)
  when "info"    then handle_info(ctx, fingerprint, args)
  when "api-key" then handle_api_key(ctx, fingerprint, args)
  when "help"    then handle_help(ctx, base_url)
  when "add-key" then handle_add_key(ctx, fingerprint, args)
  when "ssh-key" then handle_ssh_key(ctx, fingerprint, args)
  end
end
```

**Security & Access Control:**
- ✅ Ownership verification in all commands (checks `paste.ssh_fingerprint`)
- ✅ Rate limiting: paste (20/60s), login (3/600s), conn (30/60s), key ops (5/300s)
- ✅ Mutex-protected rate limiter access
- ✅ Concise error messages to stderr with exit codes

**Encryption Support:**
- ✅ Server-side encryption with PBKDF2 (100k iterations) + AES-256-GCM
- ✅ Pre-encrypted paste support (Web Crypto API compatible)
- ✅ Random password generation (32 char base64)
- ✅ IV and salt handling for Web Crypto compatibility
- ❌ Decryption in `view` command (TODO)

**Paste Management:**
- ✅ `paste` - Full featured with encryption, expiration, burn, private flags (line 273-380)
- ✅ `get` - Raw content retrieval with ownership check (line 505-530)
- ✅ `delete` - Permanent removal with ownership check (line 533-560)
- ✅ `edit` - Basic content update (line 563-612), metadata updates TODO
- ✅ `view` - Placeholder implementation (line 615-620)
- ✅ `info` - Comprehensive metadata display (line 623-655)
- ✅ `list` - Paginated list with previews (line 472-500)

### 🔧 Commands Needing Enhancement

**1. `view` Command (line 615-620)**
```crystal
# Current implementation:
private def self.handle_view(ctx, fingerprint : String, args : String) : Int32
  # For now, just use the same logic as get
  # TODO: Add decryption support in a future iteration
  handle_get(ctx, fingerprint, args)
end
```

**Enhancement Plan:**
- Parse password from `--password`, `--password-stdin`, or `PASSWORD` env var
- Decrypt encrypted pastes using existing encryption utilities
- Add error handling for wrong passwords
- Maintain ownership verification

**2. `edit` Command (line 563-612)**
```crystal
# Current implementation:
private def self.handle_edit(ctx, fingerprint : String, args : String) : Int32
  # ... ownership checks ...
  new_content = ctx.stdin
  paste.content = new_content
  paste.save
  # TODO: Add proper flag parsing for lang, title, filename updates
end
```

**Enhancement Plan:**
- Add docopt parser for `--lang`, `--title`, `--filename` flags
- Support encrypted paste re-encryption with `--password` and `--new-password`
- Update metadata fields alongside content
- Atomic save operation

## File Modifications Required

### For `view` Decryption:
- **src/ssh_server.cr** (line 615-620):
  - Add password parsing logic (env var, flag, stdin)
  - Add decryption using existing `decrypt_content` utilities
  - Proper error messages for decryption failures

### For `edit` Enhancement:
- **src/ssh_server.cr** (line 563-612):
  - Add docopt schema for edit options
  - Parse `--lang`, `--title`, `--filename` flags
  - Add encrypted paste handling (decrypt → edit → re-encrypt)
  - Update paste metadata fields

### Optional `list` Filtering:
- **src/ssh_server.cr** (line 472-500):
  - Add docopt schema for list options
  - Add filtering predicates for language, encryption, count
  - Maintain backward compatibility

## Usage Examples

### Current Fully Working Examples

```bash
# Create pastes with all features
echo "Hello World" | ssh pasto.example.com paste
cat code.py | ssh pasto.example.com paste -l python -t "My Code"
echo "secret" | ssh pasto.example.com paste --encrypted --burn --expire 1h

# List and retrieve
ssh pasto.example.com list
ssh pasto.example.com get abc123 > file.txt
ssh pasto.example.com info abc123

# Edit and delete
cat updated.txt | ssh pasto.example.com edit abc123
ssh pasto.example.com delete abc123

# API and SSH key management
ssh pasto.example.com api-key create
ssh pasto.example.com ssh-key list
ssh pasto.example.com login
```

### TODO Examples (Not Yet Working)

```bash
# View with decryption (currently shows encrypted blob)
ssh pasto.example.com view abc123 --password "secret123"
PASSWORD="secret123" ssh pasto.example.com view abc123

# Edit with metadata updates (currently only updates content)
cat new.txt | ssh pasto.example.com edit abc123 --lang python --title "New Title"

# Edit encrypted paste (not yet supported)
cat new.txt | ssh pasto.example.com edit abc123 --password "old" --new-password "new"

# List filtering (not yet supported)
ssh pasto.example.com list --language python --last 10
```


## Success Criteria

### ✅ Completed
- [x] All core commands work without TTY interaction
- [x] Proper security (ownership verification, rate limiting)
- [x] Server-side encrypted paste support
- [x] Pre-encrypted paste support (Web Crypto API compatible)
- [x] Backward compatibility maintained
- [x] Clean, non-interactive error handling
- [x] Comprehensive help documentation
- [x] Paste creation with expiration, burn-after-reading, private flags
- [x] API key management commands
- [x] SSH key management with challenge-response
- [x] Login token generation for web interface

### 🔧 In Progress / TODO
- [ ] `view` command with password-based decryption
- [ ] `edit` command with metadata updates (`--lang`, `--title`, `--filename`)
- [ ] `edit` command with encrypted paste re-encryption
- [ ] Optional `list` filtering (nice-to-have)
- [ ] Comprehensive test coverage for SSH commands

## Implementation Priorities

### High Priority (Core Functionality Gaps)
1. **`view` command decryption** - Users can't easily view encrypted pastes
   - Add password parsing from multiple sources
   - Implement decryption logic
   - Estimated effort: 2-3 hours

2. **`edit` metadata updates** - Users can't update paste metadata
   - Add docopt parsing for metadata flags
   - Update paste fields
   - Estimated effort: 1-2 hours

### Medium Priority (Enhanced Features)
3. **`edit` encrypted paste support** - Re-encryption workflow
   - Decrypt with old password
   - Re-encrypt with new password
   - Estimated effort: 2-3 hours

### Low Priority (Nice-to-Have)
4. **`list` filtering** - Better paste discovery
   - Add filter flags
   - Filter results
   - Estimated effort: 1-2 hours

5. **Test coverage** - Ensure reliability
   - Unit tests for all commands
   - Integration tests for workflows
   - Estimated effort: 4-6 hours

## Future Enhancements

### Advanced Features (Post-Core)
- [ ] `search` command for paste content search
- [ ] `export` command for bulk paste export (JSON/CSV)
- [ ] `import` command for bulk paste creation
- [ ] Syntax highlighting in `view` command (via Tartrazine)
- [ ] Paste versioning/history support
- [ ] Share command to generate temporary access links
- [ ] Stats command to show usage statistics

### Collaboration Features
- [ ] Multi-user paste sharing
- [ ] Comment/annotation support
- [ ] Diff display between paste versions
- [ ] Merge command for combining pastes

## Architecture Notes

### Design Principles Followed
- **Non-interactive by design**: All operations via flags/env vars/stdin
- **Ownership-based security**: SSH key fingerprint tracks paste ownership
- **Rate limiting everywhere**: Prevents abuse across all operations
- **Scriptable interface**: Perfect for CI/CD and automation
- **Web Crypto API compatibility**: Encryption works with browser encryption

### Key Strengths
- Clean command structure with consistent patterns
- Comprehensive rate limiting (4 separate limiters)
- Proper error handling with stderr + exit codes
- Flexible encryption (server-side or pre-encrypted)
- Rich paste metadata (language, title, filename, expiration, etc.)

### Technical Debt
- `view` command is a placeholder (line 615-620)
- `edit` command lacks metadata update support (line 563-612)
- No test coverage for SSH commands yet
- Decryption utilities exist but aren't wired to `view`

## Notes

### Design Philosophy
- **No safety nets**: Direct operations without confirmations
- **Pipe-friendly**: All operations work with stdin/stdout
- **Concise errors**: Clear but not verbose
- **Rate limited**: Prevents abuse while remaining usable

### Current Statistics
- **Total Lines**: 1068 in ssh_server.cr
- **Commands**: 13 implemented (paste, list, get, view, edit, delete, info, login, api-key, add-key, ssh-key, help)
- **Rate Limiters**: 4 separate limiters (paste, login, connection, key operations)
- **Encryption**: AES-256-GCM with PBKDF2 (100k iterations)

### Development Environment
- Crystal language with Shirk SSH framework
- Sepia for object persistence
- Docopt for CLI parsing
- RateLimiter for abuse prevention
- OpenSSL for cryptography
- Error handling follows established conventions in the codebase