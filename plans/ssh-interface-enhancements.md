# SSH Interface Enhancement Plan

## Current State
The SSH interface currently supports: `paste`, `list`, `login`, `api-key`, `add-key`, `ssh-key`, `help`. It's designed as a non-interactive stdin/stdout interface using the Shirk framework with public key authentication.

**Key Constraints:**
- No TTY/interactive prompts supported
- All operations must work via command flags and environment variables
- Safety nets are optional (user preference: "safety nets are for chickens")
- Error messages should be concise, not overly verbose

## Phase 1: Core Viewing Commands

### 1. Add `get` Command
**Purpose:** Retrieve raw paste content
```bash
ssh pasto.example.com get <paste-id> > content.txt
```
**Implementation:**
- Parse paste-id from command args
- Verify paste exists and SSH key has ownership
- Stream content to stdout (encrypted or unencrypted as-is)
- Add rate limiting for content retrieval
- Simple error messages to stderr

### 2. Add `view` Command
**Purpose:** View paste with optional decryption
```bash
# Basic view (encrypted shows raw blob)
ssh pasto.example.com view abc123

# Multiple password input methods
ssh pasto.example.com view abc123 --password "secret123"
PASSWORD="secret123" ssh pasto.example.com view abc123
echo "secret123" | ssh pasto.example.com view abc123 --password-stdin
```
**Features:**
- Basic text output (no formatting for simplicity)
- Encrypted paste support via multiple input methods
- Concise error messages for missing passwords

## Phase 2: Content Management

### 3. Add `edit` Command
**Purpose:** Update paste content via stdin (pipe-based)
```bash
# Basic content replacement
cat new_content.txt | ssh pasto.example.com edit abc123

# With metadata updates
echo "updated" | ssh pasto.example.com edit abc123 --lang python --title "Fixed version"

# Encrypted paste editing
cat new.txt | ssh pasto.example.com edit abc123 --password "old123" --new-password "new123"
```
**Implementation:**
- Read new content from stdin
- Support metadata updates via flags
- Handle encrypted paste editing (re-encryption)
- Atomic updates to prevent corruption
- No interactive confirmations

### 4. Add `delete` Command
**Purpose:** Remove paste permanently
```bash
ssh pasto.example.com delete abc123
```
**Features:**
- Direct deletion, no confirmation required by default
- Optional --confirm flag if user wants safety
- Verify ownership before deletion
- Simple success/error messages

## Phase 3: Enhanced Management

### 5. Add `info` Command
**Purpose:** Show detailed paste metadata
```bash
ssh pasto.example.com info abc123
```
**Output format:**
```
id: abc123
created: 2024-01-01T12:00:00Z
language: python
encrypted: true
size: 1234
title: My Python Script
filename: script.py
```

### 6. Enhanced `list` Command
**Current:** Keep existing functionality
**Future:** Optional simple filtering if needed
```bash
ssh pasto.example.com list
# Maintain existing format, avoid breaking changes
```

## Technical Implementation

### Command Structure Extension
```crystal
# In src/pasto_ssh.cr command parser
when "get"
  handle_get_command(args[1..-1])
when "view"
  handle_view_command(args[1..-1])
when "edit"
  handle_edit_command(args[1..-1])
when "delete"
  handle_delete_command(args[1..-1])
when "info"
  handle_info_command(args[1..-1])
```

### Security & Access Control
- **Ownership Verification:** Leverage existing SSHKey->User->Paste relationships
- **Rate Limiting:** Extend existing rate limiting to new command types
- **Error Handling:** Follow existing stderr + exit code patterns
- **Concise Errors:** Clear but not overly verbose error messages

### Encryption Support
- **Password Sources:** CLI flags, environment variables, stdin
- **Password-stdin Support:** echo "pwd" | ssh ... --password-stdin
- **Re-encryption:** Same parameters or new password via --new-password
- **Key Management:** Reuse existing encryption/decryption utilities

### File Modifications Required
1. **src/pasto_ssh.cr** - Add new command handlers
2. **src/models/paste.cr** - Add edit/delete/update methods if needed
3. **src/ssh/** - Create command handler modules (optional organization)
4. **Update help system** - Document new commands
5. **Update TODO.md** - Mark completed features
6. **Update tests** - Add SSH command tests

### Implementation Order
1. **`get` command** (simplest foundation)
2. **`delete` command** (ownership verification + removal)
3. **`edit` command** (core pipe-based functionality)
4. **`view` command** (building on get + decryption)
5. **`info` command** (metadata display)

## Usage Examples

### Basic Workflow
```bash
# Create a paste
echo "Hello World" | ssh pasto.example.com paste

# List to get ID
ssh pasto.example.com list
# Output: abc123 - 2024-01-01 - Hello World...

# Get content
ssh pasto.example.com get abc123 > file.txt

# Edit content
echo "Updated content" | ssh pasto.example.com edit abc123

# Delete when done
ssh pasto.example.com delete abc123
```

### Encrypted Paste Workflow
```bash
# Create encrypted paste
echo "Secret data" | ssh pasto.example.com paste --encrypted
# Server returns: abc123 - Password: xyz789

# View encrypted content
ssh pasto.example.com view abc123 --password "xyz789"

# Edit encrypted paste
cat new_secret.txt | ssh pasto.example.com edit abc123 --password "xyz789"

# Change encryption password
cat content.txt | ssh pasto.example.com edit abc123 --password "old" --new-password "new"
```

## Success Criteria
- All new commands work without TTY interaction
- Proper security (ownership verification, rate limiting)
- Encrypted paste support via flags/environment variables
- Backward compatibility with existing commands
- Clean, non-interactive error handling
- Comprehensive help documentation
- All tests pass

## Future Enhancements
- Add `search` command for paste content search
- Add `export` command for bulk paste export
- Add `import` command for bulk paste creation
- Add syntax highlighting options to `view` command
- Add paste versioning/history support

## Notes
- This plan respects the non-interactive nature of the current SSH implementation
- All operations are designed to be scriptable and pipe-friendly
- Security is maintained through existing access control patterns
- Error handling follows established conventions in the codebase