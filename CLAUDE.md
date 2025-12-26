# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Pasto** is a Crystal-based pastebin application with live syntax highlighting, SSH access, user accounts, MCP (Model Context Protocol) support, and extensive theming. It uses a multi-service architecture with file-based persistence via Sepia.

## Key Technologies

- **Web Framework**: Kemal (HTTP server)
- **Persistence**: Sepia (file-based object storage with versioning)
- **Syntax Highlighting**: Tartrazine (321+ themes, 35+ languages)
- **Language Detection**: Hansa (automatic language classification)
- **SSH Server**: Shirk (custom SSH implementation)
- **Styling**: Pico CSS (minimalist CSS framework)
- **Editor**: CodeJar (lightweight code editor)
- **MCP Protocol**: Native Model Context Protocol support for AI integration

## Development Commands

```bash
# Install dependencies
shards install

# Build ALL binaries (required - there are 4 binaries)
shards build pasto pasto-ssh pasto-backup pasto-crypto

# Run the web server (port 3000 by default)
./bin/pasto

# Run the SSH server (port 2222 by default)
./bin/pasto-ssh

# Run the backup tool (create user data backups)
./bin/pasto-backup --user-id=user_12345

# Run the crypto tool (encrypt/decrypt pastes)
./bin/pasto-crypto encrypt --random-pass --output encrypted.txt input.txt

# Linting and formatting
./bin/ameba --fix src/          # Auto-fix linting issues
crystal tool format src/

# Run tests
crystal spec

# Run single test file
crystal spec spec/paste_spec.cr

# Docker development
docker compose up -d             # Start both services
docker compose logs -f pasto     # View web server logs
docker compose logs -f pasto-ssh # View SSH server logs
docker compose down              # Stop services
```

## Architecture

### Multi-Binary Architecture
The project builds **FOUR separate binaries** from shard.yml targets:
1. **pasto** (`src/pasto.cr`): Main web server (Kemal) on port 3000
2. **pasto-ssh** (`src/pasto_ssh.cr`): SSH server on port 2222
3. **pasto-backup** (`src/pasto_backup.cr`): Backup tool for user data exports
4. **pasto-crypto** (`src/pasto_crypto.cr`): Encryption/decryption CLI tool

All services share the same Sepia data directory for seamless integration.

### Data Persistence (Sepia Framework)
- **No database** - file-based storage using Sepia ORM
- Data stored in `./data/` with subdirectories for each model type
- **Automatic versioning**: All paste changes create new versions (immutable history)
- **File system watching**: Services watch data directory for cross-service consistency
- **Models inherit from `Sepia::Model`**: Automatic serialization/deserialization

### Core Models (`src/models/`)
- `User`: User accounts with profiles, preferences, and API keys
- `Paste`: Pastes with metadata, encryption support, and versioning
- `SSHKey`: SSH key authentication linked to users
- `AuthToken`: Session tokens for web interface
- `ApiKey`: API keys for MCP and REST API authentication
- `SSHKeyChallenge`: Challenge-response for SSH authentication
- `Backup`: User backup metadata and tracking

### Main Source Files

#### Primary Entry Points
- `src/pasto.cr`: Web server configuration, Kemal setup, asset handling
- `src/pasto_ssh.cr`: SSH server using Shirk framework
- `src/pasto_backup.cr`: Backup utility for exporting user data
- `src/pasto_crypto.cr`: CLI for zero-knowledge encryption

#### Core Functionality
- `src/server.cr` (~2300+ lines): All HTTP routes, middleware, web handlers
- `src/paste.cr` (~1000+ lines): Paste model, rendering, highlighting, themes
- `src/ssh_server.cr`: SSH session handling, commands, authentication
- `src/mcp_server.cr`: MCP protocol server for AI assistant integration

#### Supporting Modules
- `src/api.cr`: REST API endpoints for paste management
- `src/filters.cr`: Authentication filters (session, API key)
- `src/ratelimit.cr`: Rate limiting configuration and enforcement
- `src/cache.cr`: HTML caching via pasto-cache library
- `src/user_session.cr`: Session management helpers
- `src/logging.cr`: Structured logging
- `src/profile.cr`: User profile management
- `src/preview_generator.cr`: Live preview rendering
- `src/gcm_fix.cr`: OpenSSL GCM mode extensions for encryption
- `src/time_helper.cr`: Time formatting utilities
- `src/health.cr`: Health check endpoint
- `src/mimetypes.cr`: MIME type detection
- `src/ssh_utils.cr`: SSH key utilities

#### MCP Tools (`src/mcp_tools/`)
Each MCP tool is a separate file implementing CRUD operations:
- `create_paste.cr`: Create new pastes with encryption support
- `get_paste.cr`: Retrieve paste by ID
- `list_pastes.cr`: List user's pastes with filtering
- `update_paste.cr`: Update paste content (creates new version)
- `delete_paste.cr`: Permanently delete pastes

#### Views (`src/views/`)
ECR templates (embedded Crystal):
- `layout.ecr`: Main layout with sidebar and theming
- `index.ecr`: Create paste page with live editor
- `show.ecr`: View paste with syntax highlighting
- `edit.ecr`: Edit existing paste
- `history.ecr`: Version history browser
- `profile_content.ecr`: User profile with paste listing
- `403.ecr`, `404.ecr`: Error pages
- `openapi.yaml.ecr`: API documentation
- Shared partials: `_editor_unified.ecr`, `_shared_controls.ecr`, `_security_modal.ecr`

## Configuration System

All binaries use docopt-config for unified configuration with precedence:
1. Command line arguments (highest priority)
2. Environment variables (`PASTO_*` prefix)
3. Configuration file (`pasto.yml`)
4. Default values (lowest priority)

### Web/SSH Server Configuration (`pasto`, `pasto-ssh`)

Key options from `src/pasto.cr`:
- `--port`: Web server port (default: 3000)
- `--bind`: Address to bind to (default: 0.0.0.0)
- `--ssh-port`: SSH server port (default: 2222)
- `--storage-dir`: Data storage location (default: ./data)
- `--cache-dir`: Cache directory (default: ./public/cache)
- `--theme`: Default syntax highlighting theme (default: default-dark)
- `--max-paste-size`: Maximum paste size in bytes (default: 102400)
- `--auth-debug-mode`: Auto-authenticate all requests (DEV ONLY, DO NOT USE IN PRODUCTION)
- `--disable-rate-limit`: DISABLE ALL RATE LIMITING (DEV ONLY, DO NOT USE IN PRODUCTION)
- `--instances`: Number of worker instances to run (default: 1)

Rate limiting options (all configurable):
- `--rate-paste-limit/--rate-paste-window`: Paste creation per IP (default: 10/60s)
- `--rate-paste-user-limit/--rate-paste-user-window`: Per-user paste limits (default: 30/60s)
- `--rate-paste-global-limit/--rate-paste-global-window`: Global limits (default: 100/60s)
- `--rate-highlight-limit/--rate-highlight-window`: Highlight API (default: 300/60s)
- `--rate-login-limit/--rate-login-window`: Login attempts (default: 5/300s)
- `--rate-http-limit/--rate-http-window`: General HTTP requests (default: 200/60s)
- `--rate-backup-limit/--rate-backup-window`: Backup creation (default: 1/86400s)

### Backup Tool Configuration (`pasto-backup`)
- `--user-id`: User ID to backup (required)
- `--storage-dir`: Data storage location (default: ./data)
- `--log-level`: Logging level (default: info)

### Crypto Tool Configuration (`pasto-crypto`)
The crypto tool uses environment variables or command-line options:
- `--random-pass`: Generate random password for zero-knowledge encryption
- `--password`: Password for encryption/decryption (or `PASTO_PASSWORD` env var)
- `--salt`: Base64 salt for decryption (or `PASTO_SALT` env var)
- `--iv`: Base64 IV for decryption (or `PASTO_IV` env var)
- `--output`: Output file path

## Zero-Knowledge Encryption

Pasto supports **zero-knowledge encryption** where content is encrypted client-side before sending to the server. This is implemented via the `pasto-crypto` binary and browser Web Crypto API.

### How It Works
1. **Encryption**: Use `pasto-crypto` CLI or browser Web Crypto API
2. **Algorithm**: AES-256-GCM with PBKDF2 key derivation (100,000 iterations)
3. **Server stores**: Only `encryption_iv`, `encryption_salt`, and `encryption_iterations`
4. **Server cannot decrypt**: Password never sent to server
5. **Decryption**: Client-side in browser using password
6. **GCM Fix**: `src/gcm_fix.cr` provides OpenSSL GCM auth tag support via FFI

### Encryption Workflow
```bash
# 1. Encrypt locally with random password
./bin/pasto-crypto encrypt --random-pass --output secret.enc secret.txt
# Output: PASTO_PASSWORD=xxx PASTO_SALT=xxx PASTO_IV=xxx

# 2. Create paste via SSH with encryption parameters
cat secret.enc | ssh -p 2222 pasto.example.com paste \
  --iv "$PASTO_IV" --salt "$PASTO_SALT" --iterations 100000

# 3. Share URL + password with recipient
# 4. Recipient opens URL, enters password, content decrypted in browser
```

## MCP (Model Context Protocol) Integration

Pasto provides native MCP support for AI assistant integration (Claude Desktop, etc.).

### MCP Authentication
Two authentication methods supported:
1. **API Key**: `Authorization: Bearer pasto_ak_xxxxxxxxxxxx` header
2. **Session Cookie**: Standard web session authentication

### MCP Endpoints
- **MCP Server**: `/mcp` - Main MCP protocol endpoint
- **OpenAPI Spec**: `/api-spec` - Interactive API documentation

### MCP Tools
Implemented in `src/mcp_tools/`:
- `create_paste`: Create pastes with encryption, expiration, privacy options
- `get_paste`: Retrieve paste content and metadata
- `list_pastes`: List user's pastes with filtering and pagination
- `update_paste`: Update paste content (creates new version)
- `delete_paste`: Permanently delete pastes

### Claude Desktop Configuration
```json
{
  "mcpServers": {
    "pasto": {
      "transport": "http",
      "url": "https://pasto.example.com/mcp",
      "headers": {
        "Authorization": "Bearer pasto_ak_xxxxxxxxxxxx"
      }
    }
  }
}
```

## Authentication System

Three authentication methods:
1. **Session-based**: Web interface using kemal-session (cookie-based)
2. **API Key**: `pasto_ak_*` keys for REST API and MCP
3. **SSH Key**: Public key authentication for SSH server

### Implementation Details
- `src/filters.cr`: `get_api_user()` and `get_current_user()` helpers
- `src/models/api_key.cr`: API key model with user association
- `src/models/auth_token.cr`: Session tokens
- `src/models/ssh_key.cr`: SSH key storage and validation
- `src/ssh_server.cr`: SSH key challenge-response authentication

## Code Quality Standards

### Critical Rules
- **No `not_nil!`**: Handle nilable values properly with if-else or try-catch
- **No `to_s` as crutch**: Use proper nil handling patterns, not string conversion
- **Fix linting issues**: Always run `./bin/ameba --fix src/` before committing
- **Descriptive names**: Use descriptive parameter names in blocks, not single letters
- **Docopt CLI**: Follow docopt pattern in `src/pasto.cr` for new CLI options

### Build Requirements
- **Build ALL binaries**: Use `shards build pasto pasto-ssh pasto-backup pasto-crypto`
- **Never use `--release`**: Build without optimization flag for faster compilation
- **Code must work**: Non-working code is NOT considered done
- **Test after changes**: Verify functionality before completing tasks

### Testing
- Project has **12 test files** in `spec/` directory
- Run all tests: `crystal spec`
- Run single test: `crystal spec spec/paste_spec.cr`
- Key test files:
  - `spec/paste_spec.cr`: Paste model and rendering tests
  - `spec/api_spec.cr`: REST API tests
  - `spec/rate_limiting_spec.cr`: Rate limiting tests
  - `spec/mcp_tools_spec.cr`: MCP tool tests
  - `spec/ssh_server_spec.cr`: SSH server tests
  - `spec/backup_spec.cr`: Backup functionality tests

### Dependencies
- **External libs in `lib/`**: READ-ONLY, do not modify
- **Custom by ralsina**: docopt-config, sepia, tartrazine, hansa, shirk, rate_limiter, baked_file_handler, pasto-cache, mcp
- **Third-party**: kemal, kemal-session, qr-code, stumpy_png

## Development Workflow

Standard sequence for any change:
1. Make code changes
2. Build ALL binaries: `shards build pasto pasto-ssh pasto-backup pasto-crypto`
3. Test functionality (manual or automated)
4. Fix linting: `./bin/ameba --fix src/`
5. Format code: `crystal tool format src/`
6. Run tests: `crystal spec`
7. Commit if everything works

## SSH Integration Details

### SSH Commands
Implemented in `src/ssh_server.cr`:
- `paste`: Create paste from stdin (default command)
- `login`: Link SSH key to web user account
- `help`: Show available commands

### SSH Authentication Flow
1. Client connects with SSH public key
2. Server generates challenge (`SSHKeyChallenge` model)
3. Client signs challenge with private key
4. Server verifies signature (`src/ssh_server.cr:allow_connection?`)
5. Session established, command executed

### SSH Rate Limiting
Separate rate limiters for SSH operations:
- Connection rate limit (per fingerprint)
- Paste creation rate limit
- Login attempt rate limit
- SSH key addition rate limit

## REST API

### Authentication
All API endpoints require authentication:
- **API Key**: `Authorization: Bearer pasto_ak_xxxxxxxxxxxx` header
- **Session**: Cookie-based session authentication

### API v1 Endpoints

#### User Information
- `GET /api/v1/me`: Get current user information (includes api_keys_count and pastes_count)

#### Paste Management
- `GET /api/v1/pastes`: List user's pastes (with pagination: page, limit parameters)
- `POST /api/v1/pastes`: Create new paste (JSON body with content, title, language, filename, private, encrypted, burn_after_reading)
- `GET /api/v1/pastes/:id`: Get paste details (metadata, permissions, URLs)
- `GET /api/v1/pastes/:id/content`: Get paste content only (returns text/plain)
- `PATCH /api/v1/pastes/:id`: Update paste content (owner only, requires JSON body with content field)
- `DELETE /api/v1/pastes/:id`: Delete paste (owner only)

#### Utility Endpoints
- `GET /api/languages`: List all supported languages (JSON array)
- `GET /api/themes`: List all syntax highlighting themes with variants (JSON array)
- `GET /api/qr/:id`: Generate QR code for a paste (returns PNG image)

### API Documentation
Interactive OpenAPI specification available at `/openapi.yaml`

## Asset Management

### Baked Assets
Static assets are compiled into the binary using BakedFileHandler:
- **CSS themes**: Pico CSS variants (cyberpunk, synthwave, vaporwave, etc.)
- **JavaScript**: CodeJar editor, live preview logic
- **Images**: Icons, logos
- Mount point: `/assets` path handled by `BakedFileHandler`
- Asset definition: `src/assets.cr` generates `PastoAssets` class
- Registration: `src/pasto.cr:12` adds handler to Kemal

### Cache System
- **Cache directory**: `./public/cache` (configurable via `--cache-dir`)
- **Implementation**: pasto-cache library for HTML caching
- **Cached content**: Rendered paste HTML to avoid re-highlighting
- **Invalidation**: Cache cleared on paste updates

## Theme System

### UI Themes (Pico CSS)
- 15+ color schemes: slate, zinc, gray, neutral, stone, red, orange, amber, yellow, lime, green, emerald, cyan, sky, indigo, violet, fuchsia, pink
- Light/dark/auto modes with system preference detection
- Theme selection stored in user preferences

### Syntax Highlighting Themes (Tartrazine)
- **321+ themes** available via Tartrazine library
- Popular themes: monokai, dracula, nord, solarized, github, one dark, vs code themes
- Theme mapping: `src/data/tartrazine_hljs_mapping.cr`
- Theme helper: `src/theme_helper.cr` handles theme loading and rendering
- Default theme: `default-dark` (configurable via `--theme`)

## Language Detection

Automatic language detection using **Hansa** classifier:
- **35+ languages supported**: Python, JavaScript, TypeScript, Java, C, C++, C#, Go, Rust, Ruby, PHP, Perl, Kotlin, Scala, Bash, PowerShell, SQL, HTML, CSS, JSON, YAML, Markdown, Dockerfile, etc.
- Detection in `src/paste.cr`: `detect_language()` method
- Fallback: User can override language manually
- Filename detection: Uses file extension when available

## Important Development Notes

### Key Files to Understand
- **Configuration**: `src/pasto.cr:81-150` (Config class definition)
- **Routing**: `src/server.cr` (all HTTP routes)
- **Paste model**: `src/paste.cr` (core paste logic, ~1015 lines)
- **SSH handling**: `src/ssh_server.cr` (SSH session management)
- **Authentication**: `src/filters.cr` (auth helpers for all methods)
- **Rate limiting**: `src/ratelimit.cr` and `src/rate_limit_helper.cr`

### Common Patterns
- **Sepia models**: Inherit from `Sepia::Model`, define properties with macros
- **Authentication**: Use `Pasto.get_current_user(env)` or `Pasto::Filters.get_api_user(env)`
- **Rate limiting**: Use `check_rate_limit()` helper before rate-limited operations
- **Response helpers**: `Pasto::Logging.info()`, `env.set/status/redirect`
- **nil handling**: Use `if let` patterns or explicit nil checks, NEVER `not_nil!`
- **Multi-instance**: Use `--instances` flag to run multiple worker processes

### File Locations to Know
- Models: `src/models/*.cr`
- Views: `src/views/*.ecr`
- MCP tools: `src/mcp_tools/*.cr`
- Tests: `spec/*_spec.cr`
- External dependencies: `lib/` (DO NOT MODIFY)

### Testing Tips
- Use `AUTH_DEBUG_MODE=true` environment variable to bypass authentication in tests
- Use `--disable-rate-limit` flag to disable rate limiting in development
- SSH server tests require valid SSH key setup
- MCP tool tests focus on input validation and permissions