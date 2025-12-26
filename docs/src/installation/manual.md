# Manual Installation

Install Pasto from source on Linux or macOS.

## Prerequisites

- **Crystal** 1.10 or higher
- **Shards** (Crystal package manager)
- **Libssh development files**
- **OpenSSL development files**
- **Git**

### Install Crystal

**Arch Linux:**
```bash
sudo pacman -S crystal shards
```

**Ubuntu/Debian:**
```bash
curl -sSL https://crystal-lang.org/install.sh | sudo bash
```

**macOS:**
```bash
brew install crystal shards
```

**From Source:**
See https://crystal-lang.org/install/

## Install System Dependencies

### Arch Linux

```bash
sudo pacman -S libssh openssl pcre2 yaml libxml2 zlib xz libevent gc
```

### Ubuntu/Debian

```bash
sudo apt-get install -y \
  libssl-dev \
  libssh-dev \
  libpcre2-dev \
  libyaml-dev \
  libxml2-dev \
  libz-dev \
  liblzma-dev \
  libevent-dev \
  libgc-dev \
  git
```

### macOS

```bash
brew install libssh openssl pcre2 yaml libxml2 liblzma libevent
```

## Clone and Build

```bash
# Clone the repository
git clone https://github.com/ralsina/pasto.git
cd pasto

# Install dependencies
shards install

# Build all binaries
shards build pasto pasto-ssh pasto-backup pasto-crypto pasto-cli

# (Optional) Install system-wide
sudo cp bin/pasto /usr/local/bin/
sudo cp bin/pasto-ssh /usr/local/bin/
sudo cp bin/pasto-backup /usr/local/bin/
sudo cp bin/pasto-crypto /usr/local/bin/
sudo cp bin/pasto-cli /usr/local/bin/
```

## Verify Installation

```bash
# Check versions
pasto --version
pasto-ssh --version
pasto-crypto --version
pasto-backup --version
pasto-cli --version
```

## Directory Structure

After first run, Pasto creates:

```
pasto/
├── data/                    # All data (Sepia storage)
│   ├── Pasto::User/         # User accounts
│   ├── Pasto::Paste/        # Pastes
│   ├── Pasto::SSHKey/       # SSH keys
│   ├── Pasto::ApiKey/       # API keys
│   └── ...                   # Other models
├── public/cache/            # Rendered HTML cache
├── ssh_keys/               # SSH host keys
└── sessions/               # Web sessions
```

**Important:** Backup the `data/` directory regularly!

## Running Pasto

### Development Mode

```bash
# Start web server (port 3000)
./bin/pasto

# Start SSH server (port 2222)
./bin/pasto-ssh
```

### Production Mode

```bash
# With optimization (faster startup, larger binary)
crystal build --release src/pasto.cr
./pasto
```

### Background Service

Create a systemd service:

**`/etc/systemd/system/pasto.service`:**

```ini
[Unit]
Description=Pasto Pastebin Web Server
After=network.target

[Service]
Type=simple
User=pasto
WorkingDirectory=/opt/pasto
ExecStart=/opt/pasto/bin/pasto
Restart=always
RestartSec=5
Environment=PASTO_ENV=production
Environment=PASTO_PORT=3000

[Install]
WantedBy=multi-user.target
```

**`/etc/systemd/system/pasto-ssh.service`:**

```ini
[Unit]
Description=Pasto Pastebin SSH Server
After=network.target

[Service]
Type=simple
User=pasto
WorkingDirectory=/opt/pasto
ExecStart=/opt/pasto/bin/pasto-ssh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable pasto pasto-ssh
sudo systemctl start pasto pasto-ssh
```

## Configuration

### Command-Line Options

```bash
./bin/pasto --help
```

Common options:
- `--port=3000` - Web server port
- `--bind=0.0.0.0` - Bind address
- `--storage-dir=./data` - Data directory
- `--ssh-port=2222` - SSH server port
- `--theme=monokai` - Default syntax theme
- `--env=production` - Environment (development/production)

### Environment Variables

Set environment variables or use a `.env` file:

```bash
export PASTO_PORT=3000
export PASTO_STORAGE_DIR=/var/lib/pasto/data
export PASTO_MAX_PASTE_SIZE=1048576
export PASTO_THEME=monokai
export PASTO_ENV=production
```

See [Configuration Guide](../installation/configuration.md) for all options.

## SSH Server Setup

The SSH server needs a host key. On first run, it will generate one automatically:

```bash
./bin/pasto-ssh
# Will generate SSH host key in ./ssh_keys/
```

Or generate manually:

```bash
ssh-keygen -t ed25519 -f ./ssh_keys/host_key -N ""
```

## Updating

```bash
# Pull latest changes
git pull

# Update dependencies
shards update

# Rebuild
shards build pasto pasto-ssh pasto-backup pasto-crypto pasto-cli

# Restart services
sudo systemctl restart pasto pasto-ssh
```

## Uninstalling

If installed system-wide:

```bash
sudo rm /usr/local/bin/pasto
sudo rm /usr/local/bin/pasto-ssh
sudo rm /usr/local/bin/pasto-backup
sudo rm /usr/local/bin/pasto-crypto
sudo rm /usr/local/bin/pasto-cli
```

Remove data (be careful! This deletes all pastes):

```bash
rm -rf /path/to/pasto/data
```

## Troubleshooting

### Build Errors

**Problem:** `error: libssh not found`

**Solution:** Install libssh development files:
```bash
# Ubuntu/Debian
sudo apt-get install libssh-dev

# Arch Linux
sudo pacman -S libssh

# macOS
brew install libssh
```

**Problem:** Permission denied on ports

**Solution:** Use port > 1024 or run with sudo:
```bash
./bin/pasto --port=8080
```

### Runtime Errors

**Problem:** "Failed to bind to address"

**Solution:** Check if port is already in use:
```bash
lsof -i :3000  # Check port 3000
```

**Problem:** SSH connection refused

**Solution:** Check if SSH server is running:
```bash
ps aux | grep pasto-ssh
netstat -tuln | grep 2222
```

## Next Steps

- [Configuration Guide](../installation/configuration.md)
- [Web Interface](../user-guide/web-interface.md)
- [SSH Access](../user-guide/ssh-access.md)
- [CLI Client](../user-guide/cli.md)
