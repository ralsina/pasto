# CLI Client

The `pasto-cli` tool provides a full-featured command-line interface for Pasto with enhanced features over raw SSH access.

## Installation

The CLI client is included with Pasto builds:

```bash
# From repository
shards build pasto-cli

# Binary location
./bin/pasto-cli
```

For system-wide installation:

```bash
sudo cp bin/pasto-cli /usr/local/bin/
```

## Quick Start

### Initial Setup

1. **Connect to your Pasto server:**
```bash
pasto-cli --server=pasto.example.com --ssh-port=2222 login
```

This authenticates using your SSH keys and saves credentials to `~/.config/pasto/credentials.yml`.

2. **Create your first paste:**
```bash
echo 'print("Hello, World!")' | pasto-cli paste --language=python
```

3. **List your pastes:**
```bash
pasto-cli list
```

## Authentication

### Login

Authenticate with your Pasto server using SSH keys:

```bash
# Basic login
pasto-cli --server=pasto.example.com --ssh-port=2222 login

# Auto-detect SSH host from web server
pasto-cli --server=pasto.example.com login

# Or specify SSH host explicitly
pasto-cli --ssh-host=pasto-ssh.example.com --ssh-port=2222 login
```

The login process:
1. Authenticates via SSH using your SSH keys
2. Receives API credentials from the server
3. Saves credentials to `~/.config/pasto/credentials.yml`
4. Subsequent commands use saved credentials

### Credential Storage

Credentials are stored in YAML format:

```yaml
~/.config/pasto/credentials.yml
```

Format:
```yaml
current_server: "pasto.example.com"
servers:
  pasto.example.com:
    api_key: "pasto_ak_xxxxxxxxxxxx"
    api_url: "http://pasto.example.com"
    ssh_host: "pasto.example.com"
    ssh_port: 2222
```

### Logout

Remove saved credentials:

```bash
# Logout from current server
pasto-cli logout

# Logout from specific server
pasto-cli --server=pasto.example.com logout
```

## Commands

### `paste` - Create Paste

Create a new paste from stdin or file:

```bash
# From stdin
echo 'console.log("Hello");' | pasto-cli paste --language=javascript

# From file
pasto-cli paste --file myfile.py --language=python

# With title
echo 'test' | pasto-cli paste --title "My Test Paste"

# Private paste (requires login)
echo 'secret' | pasto-cli paste --private

# Encrypted paste (zero-knowledge)
./bin/pasto-crypto encrypt --random-pass --output secret.enc secret.txt
cat secret.enc | pasto-cli paste --iv "$PASTO_IV" --salt "$PASTO_SALT"

# With expiration
echo 'temp' | pasto-cli paste --expires-in 1d
```

Options:
- `--file=PATH` - Read from file instead of stdin
- `--title=TITLE` - Paste title
- `--language=LANG` - Programming language
- `--private` - Make paste private
- `--expires-in=DURATION` - Expiration: 1h, 1d, 1w, 1m, never
- `--iv=IV` - Encryption IV (for encrypted pastes)
- `--salt=SALT` - Encryption salt (for encrypted pastes)
- `--iterations=N` - PBKDF2 iterations (default: 100000)
- `--burn` - Burn after reading

### `get` - Retrieve Paste

Get paste content and metadata:

```bash
# Get paste
pasto-cli get abc123-def456

# Get specific version
pasto-cli get abc123-def456 --version 2

# Get raw content only
pasto-cli get abc123-def456 --raw

# Save to file
pasto-cli get abc123-def456 --output myfile.py
```

Options:
- `--version=N` - Get specific version
- `--raw` - Output raw content only
- `--output=FILE` - Save to file

### `list` - List Pastes

List your pastes with filtering:

```bash
# List all pastes
pasto-cli list

# Paginated list
pasto-cli list --page 2 --limit 10

# Filter by language
pasto-cli list --language python

# Only private pastes
pasto-cli list --private-only

# Only public pastes
pasto-cli list --public-only

# Only encrypted pastes
pasto-cli list --encrypted-only
```

Options:
- `--page=N` - Page number (default: 1)
- `--limit=N` - Items per page (default: 20, max: 100)
- `--language=LANG` - Filter by language
- `--private-only` - Show only private pastes
- `--public-only` - Show only public pastes
- `--encrypted-only` - Show only encrypted pastes

### `update` - Update Paste

Update an existing paste (creates new version):

```bash
# From stdin
echo 'new content' | pasto-cli update abc123-def456

# From file
pasto-cli update abc123-def456 --file newfile.py

# With new title
echo 'content' | pasto-cli update abc123-def456 --title "New Title"

# Change language
pasto-cli update abc123-def456 --language=javascript

# Make private
pasto-cli update abc123-def456 --private
```

Options:
- `--file=PATH` - Read from file
- `--title=TITLE` - New title
- `--language=LANG` - New language
- `--private` - Make private
- `--expires-in=DURATION` - Update expiration

### `delete` - Delete Paste

Permanently delete a paste:

```bash
# Delete with confirmation
pasto-cli delete abc123-def456

# Force delete (skip confirmation)
pasto-cli delete abc123-def456 --confirm
```

**Warning**: Deletion is permanent and cannot be undone.

### `login` - Authenticate

Authenticate with Pasto server:

```bash
# Basic login
pasto-cli --server=pasto.example.com --ssh-port=2222 login

# With custom SSH host
pasto-cli --ssh-host=pasto-ssh.example.com login

# Switch servers
pasto-cli --server=another-server.com login
```

### `logout` - Remove Credentials

Remove saved credentials:

```bash
# Logout from current server
pasto-cli logout

# Logout from specific server
pasto-cli --server=pasto.example.com logout
```

### `help` - Show Help

Show command help:

```bash
# General help
pasto-cli --help

# Command-specific help
pasto-cli paste --help
pasto-cli get --help
```

## Global Options

Options available for all commands:

```bash
# Server configuration
--server=HOST          # Pasto web server
--ssh-host=HOST        # SSH server (auto-detected from --server)
--ssh-port=PORT        # SSH port (default: 2222)

# Output
--output=FILE          # Output to file (for get command)
--json                 # Output as JSON (for list/get)

# Help
--help                 # Show help
--version              # Show version
```

## Terminal Features

### Hyperlinks

The CLI uses terminal hyperlinks when supported:

```bash
pasto-cli list
```

Output:
```
🌐 My Python Script (abc123)
🔤 python
📅 2 hours ago
🔗 http://pasto.example.com/abc123-def456  # Clickable link
```

Requires terminal emulator that supports OSC-8 hyperlinks:
- iTerm2
- GNOME Terminal (v3.28+)
- Kitty
- WezTerm
- Alacritty (v0.10.0+)

### Human Timestamps

Relative time display:
- "2 hours ago"
- "3 days ago"
- "1 week ago"

### Unicode Icons

Visual indicators:
- 🌐 Public paste
- 🔐 Private paste
- 🔒 Encrypted paste
- 🔗 URL/hyperlink
- 📅 Creation time
- 🔤 Language
- ✅ Success
- ❌ Error

## Advanced Usage

### Batch Operations

```bash
# Create multiple pastes
for file in *.txt; do
    pasto-cli paste --file "$file" --title "$file"
done
```

### Scripting

```bash
#!/bin/bash
# Upload file and get URL
URL=$(cat myfile.py | pasto-cli paste --language=python)
echo "Created: $URL"

# Get paste and save
pasto-cli get abc123-def456 --output downloaded.py

# List all Python pastes
pasto-cli list --language=python
```

### Integration with Git

```bash
# Share git diff
git diff | pasto-cli paste --title "Git Diff"

# Share commit
git show HEAD | pasto-cli paste --title "Commit $(git rev-parse HEAD)"
```

### Backup Your Pastes

```bash
#!/bin/bash
# Download all your pastes
pasto-cli list --limit 100 | while read -r line; do
    id=$(echo "$line" | grep -oP '(?<=\().*(?=\))')
    pasto-cli get "$id" --output "backup/$id.txt"
done
```

## Configuration

### Credentials File

Location: `~/.config/pasto/credentials.yml`

Format:
```yaml
current_server: "pasto.example.com"
servers:
  pasto.example.com:
    api_key: "pasto_ak_xxxxxxxxxxxx"
    api_url: "http://pasto.example.com"
    ssh_host: "pasto.example.com"
    ssh_port: 2222
    last_login: "2024-12-26T10:30:00Z"
```

### Multiple Servers

You can be logged into multiple Pasto instances:

```bash
# Login to server 1
pasto-cli --server=pasto1.example.com login

# Login to server 2
pasto-cli --server=pasto2.example.com login

# Switch between servers
pasto-cli --server=pasto1.example.com list
pasto-cli --server=pasto2.example.com list
```

### Environment Variables

Override with environment variables:

```bash
export PASTO_SERVER=pasto.example.com
export PASTO_SSH_PORT=2222
export PASTO_CREDENTIALS_DIR=~/.config/pasto

# Use environment variables
pasto-cli login
pasto-cli list
```

## Troubleshooting

### Login Fails

**Problem**: `Error: SSH authentication failed`

**Solutions**:
- Verify SSH keys are configured on the server
- Check SSH server is running: `ssh -p 2222 pasto.example.com`
- Ensure correct SSH port
- Check `~/.ssh/config` for conflicting entries

### Credentials Not Found

**Problem**: `Error: No credentials found for server`

**Solutions**:
- Run `pasto-cli login` first
- Check `~/.config/pasto/credentials.yml` exists
- Verify correct `--server` parameter

### API Errors

**Problem**: `Error: API request failed: 401 Unauthorized`

**Solutions**:
- Credentials may have expired
- Run `pasto-cli logout && pasto-cli login` to re-authenticate
- Check API key is valid on server

### Connection Refused

**Problem**: `Error: Connection refused`

**Solutions**:
- Verify server is reachable: `curl http://pasto.example.com`
- Check SSH server: `ssh -p 2222 pasto.example.com`
- Ensure correct server/port

## Examples

### Complete Workflow

```bash
# 1. Login
pasto-cli --server=pasto.example.com --ssh-port=2222 login

# 2. Create paste
echo 'print("Hello")' | pasto-cli paste --language=python

# 3. List pastes
pasto-cli list

# 4. Get paste
pasto-cli get abc123-def456

# 5. Update paste
echo 'new content' | pasto-cli update abc123-def456

# 6. Delete paste
pasto-cli delete abc123-def456 --confirm
```

### Script Integration

```bash
#!/bin/bash
# Upload file and notify
SERVER="pasto.example.com"
FILE="$1"

if [ -z "$FILE" ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

URL=$(cat "$FILE" | pasto-cli --server="$SERVER" paste --title "$FILE")
echo "Uploaded to: $URL"
echo "$URL" | xclip -selection clipboard  # Copy to clipboard
```

## Next Steps

- [SSH Access](ssh-access.md) - Direct SSH interface
- [Encryption](encryption.md) - Zero-knowledge encryption
- [Web Interface](web-interface.md) - Browser-based usage
