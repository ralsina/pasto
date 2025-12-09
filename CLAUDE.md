# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Pasto** is a Crystal-based pastebin application with live syntax highlighting, SSH access, user accounts, and extensive theme support. It consists of two main services: a web server (Kemal) and an SSH server, with file-based data persistence using Sepia.

## Development Commands

```bash
# Install dependencies
shards install

# Build both binaries (required)
shards build pasto pasto-ssh

# Run the web server
./bin/pasto

# Run the SSH server
./bin/pasto-ssh

# Linting and formatting
./bin/ameba src/
crystal tool format src/

# Run tests
crystal spec

# Docker development
docker compose up -d          # Start both services
docker compose logs -f        # View logs
docker compose down           # Stop services
```

## Architecture

### Dual-Service Design
- **Web Server** (`src/pasto.cr`): HTTP interface on port 3000
- **SSH Server** (`src/pasto_ssh.cr`): SSH interface on port 2222
- Both services share the same data directory for seamless integration

### Data Persistence
- **No database** - file-based storage using Sepia framework
- Data stored in `./data/` with subdirectories for each model type
- Version history built into the storage system
- File system watching enabled for cross-service data consistency

### Key Components

#### Core Models (`src/models/`)
- `User`: User accounts with profiles and preferences
- `SSHKey`: SSH key authentication for SSH access
- `AuthToken`: Session management for web interface

#### Main Source Files
- `src/pasto.cr`: Web server entry point and configuration
- `src/pasto_ssh.cr`: SSH server entry point
- `src/server.cr`: Kemal routes and middleware (2333 lines)
- `src/paste.cr`: Core paste functionality, highlighting, themes (1015 lines)
- `src/user_session.cr`: Session management

#### Views (`src/views/`)
- ECR templates for web interface
- Live preview with CodeJar editor
- Responsive design using Pico CSS

## Configuration

Configuration follows this precedence:
1. Command line arguments
2. Environment variables (`PASTO_*` prefix)
3. Configuration file (`pasto.yml`)
4. Default values

### Key Configuration Options
- `--port`: Web server port (default: 3000)
- `--ssh-port`: SSH server port (default: 2222)
- `--storage-dir`: Data storage location (default: ./data)
- `--theme`: Default syntax highlighting theme (default: monokai)
- `--max-paste-size`: Maximum paste size in bytes (default: 102400)

## Important Development Notes

### Code Quality Standards
- **No `not_nil!`** - Handle nilable values properly
- **No `to_s` as crutch** - Use proper nil handling patterns
- **Always fix linting issues** with `ameba --fix` before commits
- **Use descriptive parameter names** in blocks
- **Docopt for CLI** - Follow the established pattern

### Build Requirements
- Build **both binaries** before declaring tasks done
- **Never use `--release`** flag for builds
- Run linter and fix issues before committing
- **Code must work** - non-working code is not considered done

### Testing
- No project-specific test files currently exist
- Tests are in Crystal standard library and dependencies
- Use `crystal spec` to run tests

### Dependencies
- All external dependencies are in `lib/` (read-only)
- Custom libraries by the same author (ralsina)
- Key dependencies: Kemal, Sepia, Tartrazine, Hansa, Shirk

## Development Workflow

1. Make changes
2. Build both binaries: `shards build pasto pasto-ssh`
3. Test functionality
4. Lint and fix: `./bin/ameba --fix src/`
5. Format code: `crystal tool format src/`
6. Run tests: `crystal spec`
7. Commit if everything works

## SSH Integration

SSH keys are automatically linked to user accounts:
- Users can create pastes via SSH: `cat file | ssh -p 2222 pasto.example.com`
- SSH keys serve as authentication identity
- Web and SSH services share the same data store

## Rate Limiting

Comprehensive rate limiting is configured:
- Per-IP limits for paste creation
- Per-user limits (higher than IP limits)
- Global limits to prevent abuse
- Separate limits for different endpoints (paste, highlight, login, HTTP)

## Asset Management

- Static assets are baked into the binary using BakedFileHandler
- Assets include CSS themes, JavaScript for live preview
- Cache directory stores rendered HTML for performance