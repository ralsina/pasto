# AGENTS.md - Guide for Working with Pasto

This document contains essential information for agents working on the Pasto codebase.

## Project Overview

Pasto is a Crystal-based pastebin application with live syntax highlighting preview and extensive theme support. It uses the Kemal web framework and provides both web and SSH interfaces for creating pastes.

## Essential Commands

### Development Commands

```bash
# Install dependencies
shards install

# Build the application
shards build

# Build in release mode
shards build --release

# Run the application
./bin/pasto

# Run with custom port
./bin/pasto --port 8080

# Run tests
crystal spec

# Code formatting
crystal tool format src/

# Linting (code style checking)
./bin/ameba src/
```

### Running the Application

```bash
# Default settings (port 3000)
./bin/pasto

# Custom configuration
./bin/pasto --port 8080 --max-paste-size 5242880 --theme dracula

# Enable SSH server
./bin/pasto --ssh-enabled=true --ssh-port=2222
```

## Code Organization

### Core Structure

```
src/
├── pasto.cr          # Main application entry point, configuration, SSH server
├── server.cr         # Kemal web server, routes, caching, rate limiting
├── paste.cr          # Paste model, syntax highlighting, themes
└── views/
    ├── layout.ecr    # Main HTML layout with sidebar and theming
    ├── index.ecr     # Paste creation form
    └── show.ecr      # Paste display page
```

### Key Dependencies

- **Kemal**: Web framework for HTTP routes and middleware
- **Tartrazine**: Syntax highlighting with 321+ themes
- **Hansa**: Language classification for auto-detection
- **Sepia**: Object serialization and storage
- **Shirk**: SSH server functionality
- **RateLimiter**: Rate limiting for abuse prevention
- **Docopt-config**: Configuration management (CLI args, env vars, config file)

## Configuration

Pasto supports three levels of configuration (highest to lowest priority):

1. Command line arguments
2. Environment variables (PASTO_*)
3. Configuration file (`pasto.yml`)
4. Default values

### Key Configuration Options

- `port`: HTTP server port (default: 3000)
- `bind`: Address to bind to (default: "0.0.0.0")
- `storage_dir`: Directory for paste storage (default: "./data")
- `cache_dir`: Directory for cached files (default: "./public/cache")
- `theme`: Default syntax theme (default: "default-dark")
- `max_paste_size`: Maximum paste size in bytes (default: 102400)
- `ssh_enabled`: Enable SSH server (default: false)
- `ssh_port`: SSH server port (default: 2222)

## Code Conventions

### Crystal Style

- Use `crystal tool format src/` for consistent formatting
- Run `./bin/ameba src/` for linting
- Follow Crystal naming conventions:
  - Classes: PascalCase
  - Methods: snake_case
  - Constants: UPPER_SNAKE_CASE
  - Variables: snake_case

### Module Organization

- All code is in the `Pasto` module
- Main classes: `Paste`, `Config`, `RateLimit`, `Cache`
- Use Crystal's type annotations where helpful

### Error Handling

- Use Crystal's exception handling with begin/rescue blocks
- Graceful fallbacks for unsupported languages/themes
- Always validate user input and size limits

## Architecture

### Paste Lifecycle

1. **Creation**: Via web form or SSH
2. **Language Detection**: Hansa classification → Tartrazine lexer mapping
3. **Storage**: Sepia serialization to filesystem
4. **Display**: Tartrazine highlighting with theme customization
5. **Caching**: HTML output cached in `public/cache/`

### Key Patterns

- **Configuration**: `Pasto.config` global accessor
- **Rate Limiting**: Per-IP limiting using `RateLimit` class
- **Theming**: Dual theming system (Pico CSS for UI, Tartrazine for syntax)
- **SSH Integration**: Separate process with shared paste creation logic

### Important Gotchas

- **Language Filtering**: Only show Tartrazine-supported languages in UI
- **SSH Keys**: Generate host keys automatically if missing
- **Content Sanitization**: Always escape HTML to prevent XSS
- **File Paths**: Use absolute paths for file operations
- **CORS/Security**: Headers set in `before_all` handler

## Testing

The project uses Crystal's built-in testing framework:

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/paste_spec.cr

# Run with verbose output
crystal spec --verbose
```

## Common Development Tasks

### Adding New Languages

1. Check if Tartrazine supports the language
2. Add mapping in `language_for_extension()` method
3. Add to `available_languages()` and `generate_language_options()`
4. Test highlighting with sample code

### Adding New Themes

1. Themes are automatically loaded from Tartrazine
2. Add popular themes to `popular_themes()` array
3. Test theme switching in web interface

### Modifying Web Interface

1. Templates use ECR (Embedded Crystal)
2. CSS uses Pico CSS framework + custom styles
3. JavaScript is inline in templates
4. Theme preferences stored in cookies and localStorage

### SSH Functionality

1. SSH server runs in separate fiber/process
2. Message handling in `on_message` callback
3. Rate limiting and logging built-in
4. Paste creation shares web logic

## File Locations

- **Config**: `pasto.yml` (main), `shard.yml` (dependencies)
- **Views**: `src/views/*.ecr`
- **Static Files**: `public/` directory
- **SSH Keys**: Repository root (`ssh_host_rsa_key*`)
- **Cache**: `public/cache/` (auto-generated)
- **Data**: `./data/` (sepia storage)

## Dependencies Management

- Use `shards` for dependency management
- Dependencies defined in `shard.yml`
- Lock file: `shard.lock`
- Override possible with `shard.override.yml`

## Environment Variables

All config options can be set via environment variables with `PASTO_` prefix:

```bash
export PASTO_PORT=8080
export PASTO_MAX_PASTE_SIZE=5242880
export PASTO_THEME=monokai
export PASTO_RATE_LIMIT=10
```

## Debugging

- Debug output includes language detection and highlighting info
- Look for `DEBUG:` prefixes in console output
- Check browser console for frontend JavaScript issues
- SSH connection events are logged with fingerprint and IP info