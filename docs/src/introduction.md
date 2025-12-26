# Introduction to Pasto

**Pasto** is a modern, feature-rich pastebin application built with Crystal, designed for developers who need a fast, secure, and flexible way to share code snippets and text.

## What is Pasto?

Pasto is a self-hosted pastebin that goes beyond simple text sharing. It provides:

- **Live syntax highlighting** with 321+ themes
- **Multiple access methods**: Web, SSH, CLI, and REST API
- **Zero-knowledge encryption** for sensitive content
- **User accounts** with paste management
- **AI assistant integration** via MCP protocol

## Key Features

### Performance & Architecture
- Built with **Crystal** for blazing-fast performance
- File-based persistence (no database required)
- Efficient caching system
- Static binary compilation

### Syntax Highlighting
- **321+ themes** powered by Tartrazine
- **Automatic language detection** (35+ languages)
- Live preview as you type

### Security & Privacy
- **Zero-knowledge encryption** - encrypt client-side
- **SSH key authentication**
- **Rate limiting**
- Private pastes with access control
- Burn-after-reading option

### Multiple Access Methods
- **Web interface** - Modern, responsive design
- **SSH access** - Create pastes from terminal
- **CLI client** - Full-featured command-line tool
- **REST API** - Integration with other tools
- **MCP support** - AI assistant integration

### User Features
- User accounts with profiles
- Paste versioning and history
- Edit your pastes
- Theme customization
- Export user data

## Quick Start

### Docker (Recommended)

```bash
git clone https://github.com/ralsina/pasto.git
cd pasto
docker compose up -d
```

Services available at:
- **Web**: http://localhost:3000
- **SSH**: `ssh -p 2222 localhost`
- **CLI**: `pasto-cli --server=localhost --ssh-port=2222 login`

### Create Your First Paste

**Via SSH:**
```bash
echo 'print("Hello, World!")' | ssh -p 2222 localhost
```

**Via CLI:**
```bash
pasto-cli --server=localhost --ssh-port=2222 login
echo 'console.log("Hello");' | pasto-cli paste --language=javascript
```

**Via Web:**
Open http://localhost:3000 in your browser

## Architecture

Pasto uses a multi-service architecture:

```
┌─────────────────┐
│   Web Server    │  Port 3000
│   (Kemal)       │  HTTP/HTTPS
└─────────────────┘
        ↓
┌─────────────────┐
│   SSH Server    │  Port 2222
│   (Shirk)       │  SSH Protocol
└─────────────────┘
        ↓
┌─────────────────┐
│   Data Store    │  File System
│   (Sepia ORM)   │  JSON-based
└─────────────────┘
```

All services share the same data directory for seamless integration.

## What Makes Pasto Different?

Unlike other pastebins:
- **Self-hosted** - You control your data
- **No database** - Simple file-based storage
- **Multiple interfaces** - Access however you prefer
- **AI-native** - Built-in MCP support for AI assistants
- **Developer-focused** - Built by developers, for developers

## Use Cases

- **Code reviews** - Share snippets with your team
- **Debugging** - Collaborate on error logs
- **Documentation** - Quick reference snippets
- **Teaching** - Share examples with students
- **AI workflows** - Provide context to AI assistants

## Next Steps

- [Installation Guide](../installation/)
- [User Guide](../user-guide/)
- [API Reference](../developer-guide/api.md)
- [Deployment](../deployment/)

## Support

- **GitHub**: https://github.com/ralsina/pasto
- **Issues**: https://github.com/ralsina/pasto/issues
- **License**: MIT
