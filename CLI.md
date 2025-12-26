# Pasto CLI

The `pasto-cli` command-line client provides a convenient way to interact with Pasto from your terminal. It supports SSH-based authentication, paste creation, retrieval, and management.

## Installation

### From Release Binaries

Download the appropriate binary for your platform from the [releases page](https://github.com/ralsina/pasto/releases):

```bash
# Linux AMD64
wget https://github.com/ralsina/pasto/releases/latest/download/pasto-cli-static-linux-amd64 -O pasto-cli
chmod +x pasto-cli

# Linux ARM64
wget https://github.com/ralsina/pasto/releases/latest/download/pasto-cli-static-linux-arm64 -O pasto-cli
chmod +x pasto-cli
```

### From Source

```bash
# Clone the repository
git clone https://github.com/ralsina/pasto.git
cd pasto

# Build the CLI
shards build pasto-cli

# The binary will be at ./bin/pasto-cli
```

### From Docker

The CLI is included in the official Docker image:

```bash
docker run --rm -v ~/.config/pasto:/root/.config/pasto ralsina/pasto:latest pasto-cli --help
```

## Quick Start

### 1. Login to a Pasto Server

```bash
# Specify the server (SSH host will be automatically derived)
pasto-cli --server=pasto.example.com login

# Or specify SSH host explicitly
pasto-cli --ssh-host=pasto.example.com --ssh-port=2222 login
```

The login process:
1. Connects via SSH to the server
2. Executes the `api-key create` command
3. Stores the API key and server details in `~/.config/pasto/credentials.yml`

**What gets saved:**
- API key
- Server URL (HTTP/HTTPS)
- SSH host
- SSH port

### 2. Create a Paste

```bash
# From stdin
echo 'print("Hello, World!")' | pasto-cli paste --title="Hello World" --language=python

# From a file
pasto-cli paste myfile.py --title="My Script" --language=python

# Private paste
pasto-cli paste secret.txt --private

# Encrypted paste (client-side encryption)
pasto-cli paste secret.txt --encrypted --iv=base64iv --salt=base64salt --iterations=100000
```

### 3. List Your Pastes

```bash
# List all pastes
pasto-cli list

# Paginated listing
pasto-cli list --page=2 --limit=50
```

The list command shows:
- Paste title
- Clickable paste ID (as hyperlink in supported terminals)
- Programming language
- Status indicators (🔒 private, 🔐 encrypted, 🔥 burn-after-reading)
- Human-readable creation time

### 4. Retrieve a Paste

```bash
# Get paste content
pasto-cli get <paste-id>

# The output includes:
# - Metadata (title, language, created date, URL)
# - Full content
# - Note: Encrypted pastes must be decrypted via web UI
```

### 5. Delete a Paste

```bash
pasto-cli delete <paste-id>
```

## Authentication Methods

### SSH Key Authentication (Recommended)

The CLI uses SSH public key authentication for secure login:

1. **Automatic SSH key detection**: The CLI searches for SSH keys in:
   - `~/.ssh/id_ed25519` (preferred)
   - `~/.ssh/id_rsa`
   - `~/.ssh/id_ecdsa`

2. **Custom SSH key**: Specify a specific key with `--ssh-key`:
   ```bash
   pasto-cli --ssh-key=~/.ssh/my_custom_key login
   ```

3. **SSH key requirements**:
   - Key must be registered on the Pasto server
   - Use the web interface or SSH to add keys to your account

### Browser-Based Login

If you prefer browser-based authentication:

```bash
pasto-cli web
```

This will:
1. Generate an authentication URL via SSH
2. Open it in your default browser
3. Allow you to complete login in the web UI
4. Enable you to run `pasto-cli login` afterward to get an API key

### Logout

```bash
pasto-cli logout
```

Clears stored credentials from `~/.config/pasto/credentials.yml`.

## Configuration

### Command-Line Options

```bash
pasto-cli --server=https://pasto.example.com \
          --ssh-host=pasto.example.com \
          --ssh-port=2222 \
          --ssh-key=~/.ssh/my_key \
          --timeout=30 \
          --verbose \
          list
```

### Environment Variables

All options can be set via environment variables with the `PASTO_CLI_` prefix:

```bash
export PASTO_CLI_SERVER=https://pasto.example.com
export PASTO_CLI_SSH_HOST=pasto.example.com
export PASTO_CLI_SSH_PORT=2222
export PASTO_CLI_SSH_KEY=~/.ssh/my_key
export PASTO_CLI_TIMEOUT=30
export PASTO_CLI_VERBOSE=true

pasto-cli list
```

### Configuration File

Create `~/.config/pasto/config.yml`:

```yaml
---
server: https://pasto.example.com
ssh_host: pasto.example.com
ssh_port: 2222
ssh_key: ~/.ssh/my_key
timeout: 30
verbose: false
```

### Configuration Precedence

Options are applied in the following order (highest to lowest priority):

1. **Command-line arguments**
2. **Environment variables** (`PASTO_CLI_*`)
3. **Configuration file** (`~/.config/pasto/config.yml`)
4. **Saved credentials** (`~/.config/pasto/credentials.yml`)
5. **Default values**

### Smart Host Derivation

For `login` and `web` commands, `--server` and `--ssh-host` automatically default to each other:

```bash
# Specify only server, SSH host is derived
pasto-cli --server=pasto.example.com login
# Uses: ssh_host=pasto.example.com

# Specify only SSH host, server is derived
pasto-cli --ssh-host=pasto.example.com login
# Uses: server=https://pasto.example.com:3000
```

## Commands Reference

### login

Authenticate via SSH and store API key:

```bash
pasto-cli login [options]
```

**Options:**
- `--server=<url>`: Pasto server URL (default: http://localhost:3000)
- `--ssh-host=<host>`: SSH server host (default: localhost)
- `--ssh-port=<port>`: SSH server port (default: 2222)
- `--ssh-key=<path>`: SSH private key file to use
- `-v, --verbose`: Show verbose output

**Example:**
```bash
pasto-cli --server=pasto.example.com --ssh-port=2222 login
```

### web

Open web interface in browser via SSH login:

```bash
pasto-cli web [options]
```

**Options:** Same as `login`

**Example:**
```bash
pasto-cli web
```

### paste

Create a new paste:

```bash
pasto-cli paste [options] [<file>]
```

**Options:**
- `--title=<title>`: Paste title
- `--language=<lang>`: Programming language for syntax highlighting
- `--private`: Make paste private
- `--encrypted`: Encrypt paste (requires `--iv`, `--salt`, `--iterations`)
- `--iv=<iv>`: Encryption IV (for encrypted pastes)
- `--salt=<salt>`: Encryption salt (for encrypted pastes)
- `--iterations=<n>`: PBKDF2 iterations (default: 100000)
- `-v, --verbose`: Show verbose output

**Examples:**
```bash
# From file
pasto-cli paste script.py --title="My Python Script" --language=python

# From stdin
echo 'console.log("Hello");' | pasto-cli paste --language=javascript

# Private paste
pasto-cli paste secret.txt --private

# Encrypted paste (requires pre-encrypted content)
pasto-cli paste encrypted.bin --encrypted --iv=... --salt=...
```

### get

Retrieve and display a paste:

```bash
pasto-cli get <id> [options]
```

**Options:**
- `-v, --verbose`: Show verbose output

**Example:**
```bash
pasto-cli get abc123
```

**Note:** Encrypted pastes will display a message to open the URL in a browser for decryption.

### list

List your pastes:

```bash
pasto-cli list [options]
```

**Options:**
- `--page=<n>`: Page number (default: 1)
- `--limit=<n>`: Items per page (default: 20)
- `-v, --verbose`: Show verbose output

**Example:**
```bash
pasto-cli list --page=1 --limit=50
```

**Output format:**
```
My Python Script (abc123) - python 🔒
  2 hours ago

My JavaScript Code (def456) - javascript
  1 day ago
```

### delete

Delete a paste:

```bash
pasto-cli delete <id> [options]
```

**Options:**
- `-v, --verbose`: Show verbose output

**Example:**
```bash
pasto-cli delete abc123
```

### logout

Clear stored credentials:

```bash
pasto-cli logout [options]
```

**Options:**
- `-v, --verbose`: Show verbose output

**Example:**
```bash
pasto-cli logout
```

## Terminal Features

### Clickable Paste IDs

In supported terminals, paste IDs in the `list` command are clickable hyperlinks.

**Supported terminals:**
- Alacritty
- GNOME Terminal
- iTerm2
- KDE Konsole
- kitty
- VS Code integrated terminal
- Windows Terminal

The CLI automatically detects terminal support and enables hyperlinks accordingly.

### Human-Readable Timestamps

All timestamps are displayed in relative human-readable format:
- "2 hours ago"
- "3 days ago"
- "1 week ago"
- etc.

## Encrypted Pastes

Pasto supports zero-knowledge encryption where the server cannot read your paste content.

### Encryption Workflow

1. **Encrypt locally** using `pasto-crypto` or browser Web Crypto API
2. **Create paste** with encryption parameters:
   ```bash
   pasto-cli paste encrypted.bin \
     --encrypted \
     --iv=base64_encoded_iv \
     --salt=base64_encoded_salt \
     --iterations=100000
   ```
3. **Share** the URL and password with recipient
4. **Recipient decrypts** in browser using the password

### Using pasto-crypto Tool

The `pasto-crypto` binary (included in releases) handles encryption:

```bash
# Encrypt with random password
pasto-crypto encrypt --random-pass --output encrypted.bin input.txt

# Output includes password, IV, and salt
# Export these as environment variables:
export PASTO_PASSWORD="..."
export PASTO_IV="..."
export PASTO_SALT="..."

# Create paste
cat encrypted.bin | pasto-cli paste --encrypted --iv="$PASTO_IV" --salt="$PASTO_SALT"
```

See [ENCRYPTION.md](ENCRYPTION.md) for detailed encryption documentation.

## Troubleshooting

### SSH Connection Issues

**Problem:** "Failed to connect to hostname:port"

**Solutions:**
1. Verify the server is running: `ssh -p 2222 pasto.example.com`
2. Check your SSH key is added to your Pasto account
3. Try with `--verbose` to see detailed connection info
4. Specify SSH key explicitly: `--ssh-key=~/.ssh/my_key`

### "Not logged in" Error

**Problem:** "Not logged in. Please run 'pasto-cli login' first."

**Solution:**
```bash
# Login again
pasto-cli --server=your-server login

# Or check saved credentials
cat ~/.config/pasto/credentials.yml
```

### Permission Denied on SSH Key

**Problem:** SSH key permissions error

**Solution:**
```bash
chmod 600 ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_rsa
```

### Terminal Hyperlinks Not Working

**Problem:** Paste IDs not clickable

**Explanation:** Hyperlinks only work in supported terminals. The CLI automatically detects support and falls back to plain text in unsupported terminals.

### API Key Invalid

**Problem:** "Authentication failed" after login

**Solution:**
```bash
# Logout and login again
pasto-cli logout
pasto-cli login
```

## Examples

### Daily Workflow

```bash
# 1. Login to your server
pasto-cli --server=pasto.example.com login

# 2. Create a quick paste from a file
pasto-cli paste script.py

# 3. List recent pastes
pasto-cli list --limit=10

# 4. Get a specific paste
pasto-cli get abc123

# 5. Delete an old paste
pasto-cli delete xyz789
```

### Automated Script Sharing

```bash
#!/bin/bash
# share-paste.sh - Share script output via Pasto

SERVER="pasto.example.com"
SCRIPT="$1"

# Run script and capture output
OUTPUT=$(bash "$SCRIPT" 2>&1)

# Create paste with output
echo "$OUTPUT" | pasto-cli --server="$SERVER" paste \
  --title="Output of $SCRIPT" \
  --language=bash
```

### Backup Your Pastes

```bash
#!/bin/bash
# backup-pastes.sh - Download all your pastes

# Get all paste IDs
pasto-cli list --limit=1000 | grep -oP '\(\K[^\)]+' | while read id; do
  # Save each paste to a file
  pasto-cli get "$id" > "backup_${id}.txt"
  echo "Backed up $id"
done
```

## Integration with Other Tools

### Vim Integration

```vim
" Share current buffer via Pasto
command! -nargs=0 PastoPaste call system('pasto-cli paste --language=vim', join(getline(1, '$'), "\n"))
```

### Emacs Integration

```elisp
(defun pasto-paste-region (start end)
  "Send region to Pasto"
  (interactive "r")
  (shell-command-on-region start end "pasto-cli paste"))
```

### fzf Integration

```bash
# Interactive paste browser
pasto-cli list --limit=1000 | fzf --delimiter ')' --with-nth 1 | \
  grep -oP '\(\K[^\)]+' | \
  xargs pasto-cli get
```

## See Also

- [README.md](README.md) - General Pasto documentation
- [ENCRYPTION.md](ENCRYPTION.md) - Zero-knowledge encryption guide
- [CONFIG.md](CONFIG.md) - Server configuration options
- [MCP Integration](README.md#ai-assistant-integration-mcp) - Using with AI assistants
