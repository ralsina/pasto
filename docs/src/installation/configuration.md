# Configuration

Pasto supports three configuration methods with the following priority order (highest to lowest):

1. **Command-line arguments**
2. **Environment variables** (with `PASTO_` prefix)
3. **Configuration file** (`pasto.yml`)
4. **Default values**

## Command-Line Options

### Web Server Options

```bash
./bin/pasto --help
```

**Essential Options:**
- `--port=PORT` - Web server port (default: 3000)
- `--bind=ADDRESS` - Bind address (default: 0.0.0.0)
- `--storage-dir=PATH` - Data directory (default: ./data)
- `--cache-dir=PATH` - Cache directory (default: ./public/cache)
- `--env=ENVIRONMENT` - Environment: development or production (default: development)

**Paste Options:**
- `--max-paste-size=BYTES` - Maximum paste size in bytes (default: 102400)
- `--theme=NAME` - Default syntax highlighting theme (default: default-dark)
- `--title-length=LENGTH` - Maximum title length (default: 100)

**SSH Options:**
- `--ssh-enabled=true/false` - Enable SSH server (default: true)
- `--ssh-port=PORT` - SSH server port (default: 2222)
- `--ssh-bind=ADDRESS` - SSH bind address (default: 0.0.0.0)

**Session Options:**
- `--session-secret=STRING` - Session secret key (generate for production!)
- `--session-timeout=SECONDS` - Session timeout (default: 604800, 7 days)

**Rate Limiting:**
- `--disable-rate-limit=true/false` - DISABLE ALL RATE LIMITING (development only!)
- `--rate-paste-limit=COUNT` - Paste creation per IP per window (default: 10)
- `--rate-paste-window=SECONDS` - Time window for paste rate limiting (default: 60)
- `--rate-paste-user-limit=COUNT` - Paste creation per user per window (default: 30)
- `--rate-paste-global-limit=COUNT` - Global paste limit per window (default: 100)
- `--rate-highlight-limit=COUNT` - Highlight API requests per window (default: 300)
- `--rate-login-limit=COUNT` - Login attempts per window (default: 5)
- `--rate-login-window=SECONDS` - Login time window (default: 300)
- `--rate-http-limit=COUNT` - General HTTP requests per window (default: 200)
- `--rate-backup-limit=COUNT` - Backup creation per user per window (default: 1)
- `--rate-backup-window=SECONDS` - Backup time window (default: 86400, 24 hours)

**Development Options:**
- `--auth-debug-mode=true/false` - Auto-authenticate all requests (NEVER use in production!)
- `--log-level=LEVEL` - Logging level: debug, info, warn, error (default: info)

## Environment Variables

All environment variables use the `PASTO_` prefix and follow the same naming convention:

```bash
export PASTO_PORT=3000
export PASTO_BIND=0.0.0.0
export PASTO_STORAGE_DIR=/var/lib/pasto/data
export PASTO_CACHE_DIR=/var/lib/pasto/cache
export PASTO_ENV=production

export PASTO_MAX_PASTE_SIZE=1048576
export PASTO_THEME=monokai
export PASTO_TITLE_LENGTH=100

export PASTO_SSH_ENABLED=true
export PASTO_SSH_PORT=2222
export PASTO_SSH_BIND=0.0.0.0

export PASTO_SESSION_SECRET="your-secret-key-here"
export PASTO_SESSION_TIMEOUT=604800

export PASTO_DISABLE_RATE_LIMIT=false
export PASTO_RATE_PASTE_LIMIT=10
export PASTO_RATE_PASTE_WINDOW=60
export PASTO_RATE_PASTE_USER_LIMIT=30
export PASTO_RATE_PASTE_GLOBAL_LIMIT=100
export PASTO_RATE_HIGHLIGHT_LIMIT=300
export PASTO_RATE_LOGIN_LIMIT=5
export PASTO_RATE_LOGIN_WINDOW=300
export PASTO_RATE_HTTP_LIMIT=200
export PASTO_RATE_BACKUP_LIMIT=1
export PASTO_RATE_BACKUP_WINDOW=86400

export PASTO_AUTH_DEBUG_MODE=false
export PASTO_LOG_LEVEL=info
```

## Configuration File

Create a `pasto.yml` file in your working directory:

```yaml
# Web Server
port: 3000
bind: "0.0.0.0"
storage_dir: ./data
cache_dir: ./public/cache
env: development

# Paste Settings
max_paste_size: 102400
theme: default-dark
title_length: 100

# SSH Server
ssh_enabled: true
ssh_port: 2222
ssh_bind: "0.0.0.0"

# Sessions
session_secret: "change-me-in-production"
session_timeout: 604800  # 7 days

# Rate Limiting
disable_rate_limit: false
rate_paste_limit: 10
rate_paste_window: 60
rate_paste_user_limit: 30
rate_paste_global_limit: 100
rate_highlight_limit: 300
rate_login_limit: 5
rate_login_window: 300
rate_http_limit: 200
rate_backup_limit: 1
rate_backup_window: 86400

# Development
auth_debug_mode: false
log_level: info
```

## Environment File (.env)

For convenience, you can use a `.env` file:

```bash
# .env
PASTO_PORT=3000
PASTO_ENV=production
PASTO_STORAGE_DIR=/var/lib/pasto/data
PASTO_SESSION_SECRET=your-secret-key-here
```

Then source it before running:

```bash
source .env
./bin/pasto
```

Or use `direnv` for automatic loading:

```bash
# .envrc
export PASTO_PORT=3000
export PASTO_ENV=production
```

## Common Configuration Scenarios

### Development Environment

```bash
./bin/pasto \
  --port 3000 \
  --env development \
  --auth-debug-mode \
  --disable-rate-limit \
  --log-level debug
```

### Production Environment

```bash
./bin/pasto \
  --port 3000 \
  --env production \
  --bind 0.0.0.0 \
  --storage-dir /var/lib/pasto/data \
  --session-secret "$(openssl rand -hex 32)" \
  --log-level info
```

### High-Traffic Instance

```yaml
# pasto.yml
port: 3000
env: production
max_paste_size: 1048576  # 1MB

# Relaxed rate limits for trusted users
rate_paste_limit: 30
rate_paste_window: 60
rate_paste_user_limit: 100
rate_highlight_limit: 1000

# Tighter login limits
rate_login_limit: 3
rate_login_window: 300
```

### Private Instance

```yaml
# pasto.yml
port: 3000
env: production

# Disable SSH for internal-only access
ssh_enabled: false

# Strict rate limits
rate_paste_limit: 5
rate_paste_window: 60

# Smaller paste size
max_paste_size: 51200
```

## Security Configuration

### Generate Secure Session Secret

```bash
# Generate a secure random session secret
openssl rand -hex 32

# Or use Crystal
crystal eval "puts Random::Secure.hex(32)"
```

### Production Checklist

- [ ] Set `env=production`
- [ ] Generate secure `session_secret`
- [ ] Enable rate limiting (`disable_rate_limit=false`)
- [ ] Disable `auth_debug_mode`
- [ ] Set appropriate `max_paste_size`
- [ ] Configure firewall rules
- [ ] Use HTTPS/reverse proxy
- [ ] Set up regular backups

## Validation

Pasto validates configuration on startup:

```bash
# Invalid port
./bin/pasto --port=abc
# Error: Invalid port number

# Missing storage directory
./bin/pasto --storage-dir=/nonexistent
# Error: Storage directory does not exist

# Invalid theme
./bin/pasto --theme=nonexistent
# Warning: Theme 'nonexistent' not found, using default
```

## Viewing Current Configuration

To see the active configuration:

```bash
# Check logs on startup
./bin/pasto
# Output includes: "Starting Pasto on port 3000, environment: production"

# Use --help to see defaults
./bin/pasto --help

# Check environment variables
env | grep PASTO_
```

## Next Steps

- [Web Interface](../user-guide/web-interface.md)
- [SSH Access](../user-guide/ssh-access.md)
- [Production Deployment](../deployment/production.md)
