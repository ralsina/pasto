# Pasto Help

Pasto is a modern pastebin with live syntax highlighting, SSH access, and advanced security features.

## 🌐 Web Interface

### Creating Pastes
- **Paste**: Enter content in the editor and click "Create Paste"
- **Language**: Auto-detected or select from 200+ languages
- **Themes**: Choose from 321+ syntax highlighting themes
- **Markdown**: Toggle between source and rendered views

### Advanced Options
- **Encryption**: End-to-end encrypted pastes (client-side only)
- **Privacy**: Private pastes accessible only to you
- **Burn after reading**: Self-destructing pastes
- **Expiration**: Set custom expiration times
- **Download**: Get files with proper extensions

## 🔐 Security Features

### Encrypted Pastes
- **Client-side encryption**: Content encrypted before sending to server
- **Zero-knowledge**: Server cannot decrypt your content
- **Key-based**: Auto-generated keys or password-based
- **SSH compatible**: Same encryption across web and SSH interfaces

### Private & Burn After Reading
- **Private**: Only you can access your private pastes
- **Burn after reading**: Automatically deleted after first view
- **Secure**: No server-side decryption for encrypted content

## 🔑 SSH Access

### Basic Usage
```bash
# Create paste from terminal
echo "Hello World" | ssh -p 2222 pasto.example.com

# Create with title and filename
cat script.py | ssh -p 2222 pasto.example.com -t "My Script" -f script.py
```

### SSH Key Management
```bash
# Login to link SSH key with web account
ssh -p 2222 pasto.example.com login

# Add new SSH key (challenge-response)
ssh -i new_key -p 2222 pasto.example.com add-key
ssh -i current_key -p 2222 pasto.example.com ssh-key response <code>

# List your SSH keys
ssh -p 2222 pasto.example.com ssh-key list

# SSH help
ssh -p 2222 pasto.example.com help
```

### Encrypted SSH Pastes
```bash
# Create encrypted paste
echo "Secret data" | ssh -p 2222 pasto.example.com paste --encrypted

# Output includes URL and encryption key for sharing
```

## 👤 User Accounts

### Profile Features
- **Web login**: SSH-based authentication
- **Paste management**: View, edit, delete your pastes
- **API keys**: Generate keys for programmatic access
- **SSH keys**: Add, view, revoke SSH keys
- **Version history**: Browse previous paste versions

### API Keys
- **Generate**: Create API keys in your profile
- **Programmatic access**: Use API keys for external tools
- **Usage tracking**: Monitor API key usage
- **Revocation**: Revoke compromised or unused keys

## ⚡ Quick Commands

### SSH Commands
- `paste` - Create new paste
- `list` - List your recent pastes
- `login` - Link SSH key with web account
- `add-key` - Add new SSH key
- `ssh-key list` - List SSH keys
- `ssh-key response <code>` - Complete key addition
- `help` - Show help

### Web Features
- **Live preview**: Real-time syntax highlighting
- **Copy**: One-click copy to clipboard
- **Download**: Export with proper filename
- **Edit**: Modify your pastes (logged in users)
- **Delete**: Remove pastes permanently

## 🔧 Configuration

### Customization
- **UI themes**: Light/dark mode switching
- **Syntax themes**: 321+ color schemes
- **Language detection**: Smart auto-detection
- **File extensions**: Automatic filename suggestions

### Rate Limiting
- **Fair use**: Prevents abuse while maintaining usability
- **Higher limits**: Logged-in users get higher limits
- **Respectful**: Wait a few minutes if you hit limits

## 📝 Getting Started

1. **Web**: Visit the main page and start pasting
2. **SSH**: Use your terminal for quick paste creation
3. **Account**: Login via SSH to unlock full features
4. **API**: Generate API keys for programmatic access

## 🛡️ Security Notes

- **HTTPS required** for encryption features in production
- **No key recovery**: Lost encryption keys mean lost data
- **Zero-knowledge**: Server cannot access encrypted content
- **Privacy**: Private pastes accessible only to owners

For detailed documentation, visit the GitHub repository or use the `help` SSH command. Happy pasting! 🚀