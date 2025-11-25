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

Pasto includes automatic rate limiting to prevent spam:

- **Default limit**: 10 pastes per minute per IP address
- **Rate limit response**: HTTP 429 (Too Many Requests) with `Retry-After: 60` header
- **IP detection**: Uses `X-Forwarded-For`, `X-Real-IP`, or remote address
- **Per-IP tracking**: Each client IP is tracked independently

The rate limiter helps prevent abuse while allowing legitimate usage patterns.