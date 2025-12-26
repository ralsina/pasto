# SSH Access

Pasto provides a powerful SSH interface for creating pastes directly from your terminal without using a web browser.

## Quick Start

### Create a Paste via SSH

The simplest way to create a paste:

```bash
# Pipe content to Pasto via SSH
echo 'print("Hello, World!")' | ssh -p 2222 localhost
```

The server returns the URL of your new paste:

```
http://localhost:3000/abc123-def456
```

### Using Files

```bash
# Pipe a file
cat myfile.py | ssh -p 2222 pasto.example.com

# Redirect input
ssh -p 2222 pasto.example.com < myfile.py

# Using process substitution
ssh -p 2222 pasto.example.com < <(echo 'console.log("Hello");')
```

## SSH Commands

### Default Command: `paste`

If you don't specify a command, `paste` is assumed:

```bash
# These are equivalent
echo 'test' | ssh -p 2222 pasto.example.com
echo 'test' | ssh -p 2222 pasto.example.com paste
```

### Create Paste with Title

```bash
cat myfile.py | ssh -p 2222 pasto.example.com paste --title "My Python Script"
```

### Set Language Manually

```bash
echo 'SELECT * FROM users' | ssh -p 2222 pasto.example.com paste --language sql
```

### Create Private Paste

Requires SSH key to be linked to a user account (see "Linking SSH Key" below):

```bash
cat secret.txt | ssh -p 2222 pasto.example.com paste --private
```

### Create Encrypted Paste (Zero-Knowledge)

```bash
# Encrypt locally first (see encryption guide)
./bin/pasto-crypto encrypt --random-pass --output secret.enc secret.txt

# Save the credentials
export PASTO_PASSWORD="generated-password"
export PASTO_SALT="base64-salt"
export PASTO_IV="base64-iv"

# Create paste with encryption
cat secret.enc | ssh -p 2222 pasto.example.com paste \
  --iv "$PASTO_IV" \
  --salt "$PASTO_SALT" \
  --iterations 100000 \
  --title "Encrypted Secret"
```

### Help Command

```bash
ssh -p 2222 pasto.example.com help
```

Shows all available commands and options.

## Authentication

### SSH Key Authentication

Pasto uses SSH public key authentication:

1. **Generate SSH key** (if you don't have one):
```bash
ssh-keygen -t ed25519 -C "your@email.com"
```

2. **Copy public key** to Pasto server (first time only):
```bash
# Automatic linking via SSH
ssh -p 2222 pasto.example.com login
```

3. **Paste your public key** into the web interface:
- Visit `http://pasto.example.com/profile`
- Click "Add SSH Key"
- Paste `~/.ssh/id_ed25519.pub` contents
- Click "Add"

### Linking SSH Key to Account

To link your SSH key to your web account:

```bash
# Via SSH
ssh -p 2222 pasto.example.com login

# Or via web interface
# Visit /profile and click "Add SSH Key"
```

After linking, you can:
- Create private pastes via SSH
- Have pastes attributed to your account
- Manage your SSH keys in the web interface

### Multiple SSH Keys

You can add multiple SSH keys to your account:

1. Visit `/profile`
2. Click "Add SSH Key"
3. Paste additional public key
4. Repeat for each key

This is useful for:
- Multiple devices (laptop, desktop, phone)
- Different key types (ed25519, rsa, ecdsa)
- Backup keys

## SSH Configuration

### Simplify with `~/.ssh/config`

Add an entry to your SSH config:

```ssh
Host pasto
    HostName pasto.example.com
    Port 2222
    User pasto
    IdentityFile ~/.ssh/id_ed25519
```

Then use the short alias:

```bash
# Create paste
echo 'test' | ssh pasto

# Login
ssh pasto login
```

### Custom SSH Port

If Pasto is running on a non-standard port:

```bash
# Specify port with -p
echo 'test' | ssh -p 2222 pasto.example.com

# Or in ssh config
Host pasto
    HostName pasto.example.com
    Port 2222
```

## Advanced Usage

### Combining with Other Commands

```bash
# Git diff
git diff HEAD~1 HEAD | ssh -p 2222 pasto.example.com paste --title "Git Diff"

# Command output
ps aux | ssh -p 2222 pasto.example.com paste --language bash --title "Running Processes"

# Multiple files
cat file1.txt file2.txt | ssh -p 2222 pasto.example.com paste --title "Combined Files"

# Grep results
grep -r "TODO" src/ | ssh -p 2222 pasto.example.com paste --title "TODO Comments"
```

### Creating Aliases

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Simple pasto alias
pasto() {
    cat "$@" | ssh -p 2222 pasto.example.com
}

# Or with title support
pasto() {
    local title="${1:-Untitled}"
    cat | ssh -p 2222 pasto.example.com paste --title "$title"
}
```

Usage:

```bash
# Pipe to alias
cat file.py | pasto

# Or with title
echo 'test' | pasto "My Paste Title"
```

### Batch Operations

```bash
# Create pastes from multiple files
for file in *.txt; do
    echo "Creating paste for $file"
    cat "$file" | ssh -p 2222 pasto.example.com paste --title "$file"
done
```

### Integration with Text Editors

#### Vim

```vim
" Create paste from visual selection
vmap <leader>p :w !ssh -p 2222 pasto.example.com paste<CR>

" Create paste from entire buffer
nmap <leader>p :w !ssh -p 2222 pasto.example.com paste<CR>
```

#### Emacs

```elisp
(defun pasto-region (beginning end)
  "Send region to Pasto via SSH"
  (interactive "r")
  (shell-command-on-region beginning end "ssh -p 2222 pasto.example.com paste"))

(global-set-key (kbd "C-c p") 'pasto-region)
```

#### VS Code

Add to `keybindings.json`:

```json
{
  "key": "ctrl+shift+p",
  "command": "workbench.action.terminal.sendSequence",
  "args": {
    "sequence": "ssh -p 2222 pasto.example.com paste '${selectedText}'\n"
  }
}
```

## Troubleshooting

### Connection Refused

**Problem**: `ssh: connect to host localhost port 2222: Connection refused`

**Solution**:
- Check SSH server is running: `ps aux | grep pasto-ssh`
- Check port is correct: `netstat -tuln | grep 2222`
- Verify firewall allows port 2222

### Permission Denied (publickey)

**Problem**: `Permission denied (publickey)`

**Solution**:
- Verify SSH key is added to your account
- Check SSH key path: `ssh -v -p 2222 pasto.example.com`
- Ensure using correct identity file: `ssh -i ~/.ssh/id_ed25519 -p 2222 pasto.example.com`

### Host Key Verification Failed

**Problem**: `Offending ECDSA key in ~/.ssh/known_hosts`

**Solution**:
```bash
# Remove old host key
ssh-keygen -R "[localhost]:2222"

# Or disable host key checking (not recommended)
ssh -o StrictHostKeyChecking=no -p 2222 pasto.example.com
```

### Connection Timeout

**Problem**: `ssh: connect to host localhost port 2222: Connection timed out`

**Solution**:
- Check network connectivity
- Verify pasto-ssh is running
- Check firewall rules
- Ensure correct host/port

### Paste Not Created

**Problem**: SSH connection succeeds but no paste URL returned

**Solution**:
- Check pasto-ssh logs: `docker compose logs -f pasto-ssh` (if using Docker)
- Verify data directory is writable
- Check rate limiting (may be temporarily blocked)
- Ensure content is not empty

## SSH Server Configuration

### Server-Side Options

Configure the SSH server in `pasto.yml` or via environment variables:

```yaml
ssh_enabled: true
ssh_port: 2222
ssh_bind: "0.0.0.0"
```

Or:

```bash
export PASTO_SSH_ENABLED=true
export PASTO_SSH_PORT=2222
export PASTO_SSH_BIND=0.0.0.0
```

### Host Key Location

SSH host keys are stored in:

```bash
./ssh_keys/host_key  # Default location
```

Generate manually if needed:

```bash
ssh-keygen -t ed25519 -f ./ssh_keys/host_key -N ""
```

### Rate Limiting

SSH operations have separate rate limits:

```yaml
rate_paste_limit: 10
rate_paste_window: 60
```

Adjust in configuration or environment variables.

## Security Considerations

### SSH Key Security

- **Never share private keys** - Keep `id_ed25519` secret
- **Use passphrases** - Protect SSH keys with strong passphrases
- **Rotate keys regularly** - Update SSH keys periodically
- **Revoke compromised keys** - Remove from `/profile` immediately

### Zero-Knowledge Encryption

For sensitive content, always use zero-knowledge encryption:

```bash
# Encrypt locally
./bin/pasto-crypto encrypt --random-pass --output encrypted.enc input.txt

# Save credentials (keep safe!)
export PASTO_PASSWORD="..."
export PASTO_SALT="..."
export PASTO_IV="..."

# Upload via SSH
cat encrypted.enc | ssh -p 2222 pasto.example.com paste \
  --iv "$PASTO_IV" \
  --salt "$PASTO_SALT" \
  --iterations 100000
```

See [Encryption Guide](encryption.md) for complete instructions.

## Next Steps

- [CLI Client](cli.md) - Command-line client with more features
- [Encryption](encryption.md) - Zero-knowledge encryption guide
- [Web Interface](web-interface.md) - Browser-based usage
