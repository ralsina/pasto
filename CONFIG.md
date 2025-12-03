# Configuration

Pasto supports flexible configuration through command line arguments, environment variables, and configuration files. Configuration values are loaded with the following precedence (highest to lowest):

1. **Command line arguments** - Always take precedence
2. **Environment variables** - Prefixed with `PASTO_`
3. **Configuration file** - `pasto.yml` in the current directory
4. **Default values** - Built-in defaults

## Configuration File

Create a `pasto.yml` file in your project directory to customize settings:

```yaml
# Pasto Configuration File
# Configuration values are loaded in this order of precedence:
# 1. Command line arguments (highest)
# 2. Environment variables (PASTO_*)
# 3. This configuration file
# 4. Default values (lowest)

# Server configuration
port: 3000
bind: "0.0.0.0"

# Directory settings
storage_dir: "./data"
cache_dir: "./public/cache"

# Application settings
env: "development"
theme: "default-dark"

# Limits and security
max_paste_size: 102400  # 100KB maximum paste size
```

## Environment Variables

All configuration options can be set via environment variables with the `PASTO_` prefix:

```bash
# Set theme and port via environment variables
export PASTO_THEME=github
export PASTO_PORT=8080
export PASTO_ENV=production

./bin/pasto
```

### Available Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PASTO_PORT` | Port to listen on | 3000 |
| `PASTO_BIND` | Address to bind to | 0.0.0.0 |
| `PASTO_STORAGE_DIR` | Directory to store pastes | ./data |
| `PASTO_CACHE_DIR` | Directory for cached files | ./public/cache |
| `PASTO_ENV` | Environment (development/production) | development |
| `PASTO_THEME` | Syntax highlighting theme | default-dark |
| `PASTO_MAX_PASTE_SIZE` | Maximum paste size in bytes | 102400 |
| `PASTO_RATE_PASTE_LIMIT` | Max paste creations per IP per window | 10 |
| `PASTO_RATE_PASTE_WINDOW` | Window in seconds for paste limit | 60 |
| `PASTO_RATE_PASTE_USER_LIMIT` | Max paste creations per user per window | 30 |
| `PASTO_RATE_PASTE_USER_WINDOW` | Window in seconds for user paste limit | 60 |
| `PASTO_RATE_PASTE_GLOBAL_LIMIT` | Max global paste creations per window | 100 |
| `PASTO_RATE_PASTE_GLOBAL_WINDOW` | Window in seconds for global paste limit | 60 |
| `PASTO_RATE_HIGHLIGHT_LIMIT` | Max highlight requests per IP per window | 300 |
| `PASTO_RATE_HIGHLIGHT_WINDOW` | Window in seconds for highlight limit | 60 |
| `PASTO_RATE_LOGIN_LIMIT` | Max login attempts per IP per window | 5 |
| `PASTO_RATE_LOGIN_WINDOW` | Window in seconds for login limit | 300 |
| `PASTO_RATE_HTTP_LIMIT` | Max HTTP requests per IP per window | 200 |
| `PASTO_RATE_HTTP_WINDOW` | Window in seconds for HTTP limit | 60 |

## Command Line Arguments

All options can also be set via command line arguments:

```bash
./bin/pasto --help
```

### Usage Examples

```bash
# Start with default settings
./bin/pasto

# Start on a different port
./bin/pasto --port=8080

# Use a different theme
./bin/pasto --theme=github

# Production mode
./bin/pasto --env=production --port=80

# Custom storage directory
./bin/pasto --storage-dir=/var/lib/pasto --cache-dir=/var/cache/pasto
```

## Configuration Precedence Examples

The following examples demonstrate how configuration precedence works:

### Example 1: CLI overrides everything

```bash
# pasto.yml has port: 3000
# PASTO_PORT=8080
./bin/pasto --port=9000
# Result: port 9000 (CLI wins)
```

### Example 2: Environment variables override config file

```bash
# pasto.yml has port: 3000
export PASTO_PORT=8080
./bin/pasto
# Result: port 8080 (env var wins)
```

### Example 3: Config file provides defaults

```bash
# pasto.yml has port: 3000, theme: github
./bin/pasto
# Result: port 3000, theme: github (from config file)
```

### Example 4: Mixed configuration

```bash
# pasto.yml: port: 3000, theme: monokai, env: development
export PASTO_THEME=github
./bin/pasto --env=production
# Result: port 3000 (config file), theme: github (env var), env: production (CLI)
```

## Available Themes

Pasto supports various syntax highlighting themes through Tartrazine. Some popular themes include:

- `default-dark` (default)
- `github`
- `monokai`
- `base16-dark`
- `base16-light`
- `material`
- `nord`

You can set themes via any configuration method:

```bash
# Via CLI
./bin/pasto --theme=github

# Via environment
export PASTO_THEME=monokai

# Via config file
echo "theme: \"github\"" >> pasto.yml
```

## Security Features

### Paste Size Limits

Pasto enforces maximum paste sizes to prevent abuse:

- **Default limit**: 100KB (102,400 bytes)
- **Configurable**: Set via `--max-paste-size` option, `PASTO_MAX_PASTE_SIZE` environment variable, or `max_paste_size` in config file
- **HTTP Status**: Returns 413 (Payload Too Large) when exceeded

```bash
# Set a smaller limit for personal use
./bin/pasto --max-paste-size=51200  # 50KB

# Set a larger limit for enterprise use
export PASTO_MAX_PASTE_SIZE=1048576  # 1MB
```

### Rate Limiting

Pasto includes comprehensive rate limiting to prevent abuse across multiple vectors. All rate limiters use a sliding window algorithm for smooth traffic shaping.

#### Web Server Rate Limits

| Option | Environment Variable | Default | Description |
|--------|---------------------|---------|-------------|
| `--rate-paste-limit` | `PASTO_RATE_PASTE_LIMIT` | 10 | Max paste creations per IP per window |
| `--rate-paste-window` | `PASTO_RATE_PASTE_WINDOW` | 60 | Window in seconds for paste limit |
| `--rate-paste-user-limit` | `PASTO_RATE_PASTE_USER_LIMIT` | 30 | Max paste creations per user per window |
| `--rate-paste-user-window` | `PASTO_RATE_PASTE_USER_WINDOW` | 60 | Window in seconds for user paste limit |
| `--rate-paste-global-limit` | `PASTO_RATE_PASTE_GLOBAL_LIMIT` | 100 | Max global paste creations per window |
| `--rate-paste-global-window` | `PASTO_RATE_PASTE_GLOBAL_WINDOW` | 60 | Window in seconds for global paste limit |
| `--rate-highlight-limit` | `PASTO_RATE_HIGHLIGHT_LIMIT` | 300 | Max highlight requests per IP per window |
| `--rate-highlight-window` | `PASTO_RATE_HIGHLIGHT_WINDOW` | 60 | Window in seconds for highlight limit |
| `--rate-login-limit` | `PASTO_RATE_LOGIN_LIMIT` | 5 | Max login attempts per IP per window |
| `--rate-login-window` | `PASTO_RATE_LOGIN_WINDOW` | 300 | Window in seconds for login limit (5 min) |
| `--rate-http-limit` | `PASTO_RATE_HTTP_LIMIT` | 200 | Max HTTP requests per IP per window |
| `--rate-http-window` | `PASTO_RATE_HTTP_WINDOW` | 60 | Window in seconds for HTTP limit |

#### SSH Server Rate Limits

| Option | Environment Variable | Default | Description |
|--------|---------------------|---------|-------------|
| `--rate-ssh-paste-limit` | `PASTO_RATE_SSH_PASTE_LIMIT` | 20 | Max paste creations per key per window |
| `--rate-ssh-paste-window` | `PASTO_RATE_SSH_PASTE_WINDOW` | 60 | Window in seconds for SSH paste limit |
| `--rate-ssh-login-limit` | `PASTO_RATE_SSH_LOGIN_LIMIT` | 3 | Max login/token requests per key per window |
| `--rate-ssh-login-window` | `PASTO_RATE_SSH_LOGIN_WINDOW` | 600 | Window in seconds for SSH login limit (10 min) |
| `--rate-ssh-conn-limit` | `PASTO_RATE_SSH_CONN_LIMIT` | 30 | Max connections per IP per window |
| `--rate-ssh-conn-window` | `PASTO_RATE_SSH_CONN_WINDOW` | 60 | Window in seconds for SSH connection limit |

#### Rate Limit Behavior

- **HTTP Status**: Returns 429 (Too Many Requests) when limit exceeded
- **Headers**: All responses include rate limit headers:
  - `X-RateLimit-Remaining`: Requests remaining in current window
  - `X-RateLimit-Reset`: Unix timestamp when window resets
  - `Retry-After`: Seconds until rate limit resets (on 429 responses)
- **IP Detection**: Uses `X-Forwarded-For`, `X-Real-IP`, or remote address
- **Logging**: All rate limit hits are logged for monitoring
- **Excluded Paths**: `/highlight`, `/cache/*`, `/favicon.ico`, and `/syntax-theme.css` are excluded from HTTP rate limiting (but `/highlight` has its own dedicated limiter)

#### Rate Limit Configuration Examples

```yaml
# pasto.yml - Stricter limits for public instance
rate_paste_limit: 5
rate_paste_window: 60
rate_http_limit: 100
rate_login_limit: 3
rate_login_window: 600
```

```bash
# Environment variables for high-traffic instance
export PASTO_RATE_PASTE_LIMIT=50
export PASTO_RATE_PASTE_GLOBAL_LIMIT=500
export PASTO_RATE_HTTP_LIMIT=1000

./bin/pasto
```

```bash
# CLI for development (relaxed limits)
./bin/pasto --rate-paste-limit=100 --rate-http-limit=1000
```

#### Rate Limit Design Notes

- **Highlight endpoint** has a high limit (300/60s) because the live preview refreshes frequently while editing
- **Login attempts** have a long window (5-10 minutes) to prevent brute-force attacks
- **Global paste limit** prevents coordinated abuse from multiple IPs
- **SSH and HTTP limits are separate** as they run in different processes
- **User limits** are tracked by authenticated user ID when available
