# Pasto

A Crystal-based pastebin application with live syntax highlighting, SSH access, user accounts, and extensive theme support.

![Pasto](https://img.shields.io/badge/Crystal-000000?style=for-the-badge&logo=crystal&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

## Features

### Core Features
- 🚀 **Fast & Lightweight**: Built with Crystal for excellent performance
- 🎨 **Live Preview**: Real-time syntax highlighting as you type
- 🌈 **Extensive Theming**: 321+ syntax highlighting themes from Tartrazine
- 🎭 **Smart Language Detection**: Auto-detects language with Hansa classification
- 📱 **Responsive Design**: Works beautifully on desktop and mobile
- 🔒 **Built-in Security**: Rate limiting and size validation

### SSH Access
- 🔑 **SSH Paste Creation**: Create pastes directly via SSH (`cat file | ssh pasto.example.com`)
- 👤 **SSH Key Authentication**: Your SSH key becomes your identity
- 🔗 **Automatic Account Linking**: SSH keys automatically linked to user accounts

### User Accounts & Profiles
- 📋 **User Profiles**: View and manage all your pastes in one place
- ✏️ **Editable Display Names**: Personalize your profile
- 🎨 **Theme Preferences**: UI and syntax theme preferences saved per user
- 🔐 **Session Management**: Secure web sessions with cookie-based auth

### Paste Management
- 📝 **Paste Titles**: Add optional titles or auto-generate from content
- 📜 **Version History**: Full edit history with Sepia versioning
- 🕐 **View Past Versions**: Browse and compare previous versions
- ✏️ **Edit Your Pastes**: Modify pastes you own
- 🗑️ **Delete Pastes**: Remove pastes from your profile

### Modern UI
- 🎯 **Clean Interface**: Modern design with Pico CSS and Lucide icons
- 📐 **Collapsible Sidebar**: Theme controls in a space-saving sidebar
- ⌨️ **CodeJar Editor**: Lightweight code editor with syntax highlighting
- 🔄 **Live Preview Pane**: See rendered output as you type

## Quick Start

### Docker (Recommended)

The easiest way to run Pasto is with Docker Compose:

```bash
# Clone the repository
git clone https://github.com/ralsina/pasto.git
cd pasto

# Start Pasto (web + SSH server)
docker compose up -d

# View logs
docker compose logs -f

# Stop Pasto
docker compose down
```

The services will be available at:

- **Web interface**: <http://localhost:3000>
- **SSH access**: `ssh -p 2222 localhost`

#### Docker Configuration

The `docker-compose.yml` file includes:

- **pasto** service: Web interface on port 3000
- **pasto-ssh** service: SSH server on port 2222
- **Persistent volumes** for data, sessions, cache, and SSH keys

To customize, edit the environment variables in `docker-compose.yml`:

```yaml
environment:
  PASTO_PORT: 3000
  PASTO_MAX_PASTE_SIZE: 1048576  # 1MB
  PASTO_THEME: monokai
  PASTO_RATE_LIMIT: 10
  PASTO_SESSION_SECRET: "your-secret-here"  # Change in production!
```

#### Volumes

| Volume | Path | Description |
|--------|------|-------------|
| `pasto-data` | `/app/data` | Pastes, users, SSH keys (back this up!) |
| `pasto-sessions` | `/app/sessions` | Web sessions |
| `pasto-cache` | `/app/public/cache` | Rendered HTML cache |
| `pasto-ssh-keys` | `/app/ssh-keys` | SSH host keys |

#### Backup

```bash
# Backup all data
docker compose exec pasto tar -czf - /app/data > pasto-backup.tar.gz

# Or copy volumes
docker run --rm -v pasto-data:/data -v $(pwd):/backup alpine \
  tar -czf /backup/pasto-data-backup.tar.gz /data
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/ralsina/pasto.git
cd pasto

# Install dependencies
shards install

# Build the application
shards build --release

# Run the server
./bin/pasto
```

### SSH Usage

Create a paste via SSH:

```bash
# Simplest form - just pipe content
cat myfile.py | ssh -p 2222 pasto.example.com

# Or use echo
echo "Hello, World!" | ssh -p 2222 pasto.example.com

# Redirect from file
ssh -p 2222 pasto.example.com < myfile.py

# Explicit paste command (also works)
cat myfile.py | ssh -p 2222 pasto.example.com paste
```

The server returns the URL of your new paste.

Other SSH commands:

```bash
# Login to link SSH key with web account
ssh -p 2222 pasto.example.com login

# Show help
ssh -p 2222 pasto.example.com help
```

### Web Usage

1. Navigate to `http://localhost:3000`
2. Type or paste your code in the editor
3. Watch the live preview update
4. Click **+** to create the paste

## Configuration

Pasto supports three configuration methods (in order of priority):

1. **Command line arguments**
2. **Environment variables** (prefixed with `PASTO_`)
3. **Configuration file** (`pasto.yml`)

### Command Line Options

```bash
./bin/pasto \
  --port 3000 \
  --bind 0.0.0.0 \
  --max-paste-size 102400 \
  --theme default-dark \
  --ssh-enabled true \
  --ssh-port 2222 \
  --storage-dir ./data \
  --cache-dir ./public/cache
```

### Environment Variables

```bash
export PASTO_PORT=3000
export PASTO_MAX_PASTE_SIZE=102400
export PASTO_THEME=monokai
export PASTO_SSH_ENABLED=true
export PASTO_SSH_PORT=2222
export PASTO_RATE_LIMIT=10
```

### Configuration File (`pasto.yml`)

```yaml
port: 3000
bind: "0.0.0.0"
max_paste_size: 102400  # 100KB
theme: default-dark
ssh_enabled: true
ssh_port: 2222
storage_dir: ./data
cache_dir: ./public/cache
rate_limit: 10
rate_window: 60
```

## API Endpoints

### Create Paste (Web)

```bash
curl -X POST http://localhost:3000 \
  -d "content=print('Hello!')&language=python&title=My%20Paste"
```

### View Paste

```bash
# View paste
curl http://localhost:3000/{paste-id}

# View with language override
curl http://localhost:3000/{paste-id}?lang=python

# View with file extension
curl http://localhost:3000/{paste-id}.py
```

### View Paste History

```bash
# View all versions (owner only)
curl http://localhost:3000/{paste-id}/history

# View specific version
curl http://localhost:3000/{paste-id}/version/1
```

### Live Highlighting API

```bash
curl -X POST http://localhost:3000/highlight \
  -d "content=def hello(): pass&language=python&theme=monokai"
```

## Supported Languages

Pasto supports 35+ programming languages including:

- **Popular**: Python, JavaScript, TypeScript, Java, C, C++, C#, Go, Rust
- **Web**: HTML, CSS, SCSS, Sass, JSON, XML, YAML, Markdown
- **Systems**: Bash, Shell, PowerShell, Dockerfile
- **Data**: SQL, MySQL, PostgreSQL, CSV
- **And more**: PHP, Ruby, Perl, Kotlin, Scala, ActionScript...

*Only languages with working Tartrazine lexers are available.*

## Theme Support

### UI Themes (Pico CSS)
- 15 color schemes: Slate, Zinc, Gray, Neutral, Stone, Red, Orange, Amber, Yellow, Lime, Green, Emerald, Cyan, Sky, Indigo, Violet, Fuchsia, Pink
- Light/Dark/Auto modes with system preference detection

### Syntax Themes (Tartrazine)
- 321+ themes including popular ones like Dracula, Monokai, Nord, Solarized, One Dark, GitHub, VS Code themes, and many more

## Project Structure

```
pasto/
├── src/
│   ├── pasto.cr           # Entry point, configuration
│   ├── server.cr          # Kemal routes and middleware
│   ├── paste.cr           # Paste model, highlighting, themes
│   ├── pasto_ssh.cr       # SSH server entry point
│   └── views/
│       ├── layout.ecr     # Main layout with sidebar
│       ├── index.ecr      # Create paste page
│       ├── show.ecr       # View paste page
│       ├── edit.ecr       # Edit paste page
│       ├── history.ecr    # Version history page
│       └── profile_content.ecr  # User profile
├── data/                  # Sepia storage directory
├── public/cache/          # Cached rendered pastes
├── sessions/              # Session storage
└── pasto.yml              # Configuration file
```

## Development

```bash
# Install dependencies
shards install

# Build
shards build

# Build release
shards build --release

# Run tests
crystal spec

# Format code
crystal tool format src/

# Lint
./bin/ameba src/
```

## Security Features

- **Rate Limiting**: Configurable per-IP rate limits
- **Size Validation**: Maximum paste size enforcement
- **HTML Escaping**: All content properly sanitized
- **Session Security**: Secure cookie-based sessions
- **SSH Key Auth**: Public key authentication for SSH access

## Dependencies

- **[Kemal](https://kemalcr.com/)**: Web framework
- **[Tartrazine](https://github.com/ralsina/tartrazine)**: Syntax highlighting (321+ themes)
- **[Hansa](https://github.com/ralsina/hansa)**: Language classification
- **[Sepia](https://github.com/ralsina/sepia)**: Object persistence with versioning
- **[Shirk](https://github.com/ralsina/shirk)**: SSH server
- **[Pico CSS](https://picocss.com/)**: Minimal CSS framework
- **[Lucide](https://lucide.dev/)**: Icon library
- **[CodeJar](https://medv.io/codejar/)**: Code editor

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Created by [Roberto Alsina](https://github.com/ralsina)

---

**Pasto** - Modern pastebin with SSH access and live preview.
