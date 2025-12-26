# Docker Installation

Docker is the recommended way to run Pasto. It provides pre-built, optimized images with all dependencies included.

## Prerequisites

- Docker Engine 20.10 or higher
- Docker Compose v2.0 or higher

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/ralsina/pasto.git
cd pasto
```

### 2. Start with Docker Compose

```bash
docker compose up -d
```

This starts two services:
- **pasto** - Web server on port 3000
- **pasto-ssh** - SSH server on port 2222

### 3. Verify It's Running

```bash
# Check logs
docker compose logs -f

# Test web interface
curl http://localhost:3000

# Test SSH
ssh -p 2222 localhost
```

## Docker Compose Configuration

The default `docker-compose.yml` includes:

```yaml
services:
  pasto:
    image: ralsina/pasto:latest
    ports:
      - "3000:3000"
    volumes:
      - pasto-data:/app/data
      - pasto-cache:/app/public/cache
      - pasto-sessions:/app/sessions
    environment:
      - PASTO_PORT=3000
      - PASTO_ENV=production

  pasto-ssh:
    image: ralsina/pasto:latest
    ports:
      - "2222:2222"
    volumes:
      - pasto-data:/app/data
      - pasto-ssh-keys:/app/ssh_keys
    environment:
      - PASTO_SSH_ENABLED=true
      - PASTO_SSH_PORT=2222
      - PASTO_ENV=production

volumes:
  pasto-data:
  pasto-cache:
  pasto-sessions:
  pasto-ssh-keys:
```

## Customization

### Environment Variables

Edit `docker-compose.yml` to customize:

```yaml
environment:
  # Server Configuration
  - PASTO_PORT=3000
  - PASTO_BIND=0.0.0.0
  - PASTO_ENV=production

  # Storage
  - PASTO_STORAGE_DIR=/app/data
  - PASTO_CACHE_DIR=/app/public/cache

  # SSH
  - PASTO_SSH_ENABLED=true
  - PASTO_SSH_PORT=2222
  - PASTO_SSH_BIND=0.0.0.0

  # Limits
  - PASTO_MAX_PASTE_SIZE=1048576  # 1MB

  # Theme
  - PASTO_THEME=monokai

  # Session
  - PASTO_SESSION_SECRET=change-me-in-production

  # Rate Limiting
  - PASTO_DISABLE_RATE_LIMIT=false
  - PASTO_RATE_PASTE_LIMIT=10
  - PASTO_RATE_PASTE_WINDOW=60
```

### Build Your Own Image

If you want to build from source:

```bash
docker build -t my-pasto .
```

Then use it in `docker-compose.yml`:

```yaml
services:
  pasto:
    image: my-pasto
```

## Volumes

### Data Volume (`pasto-data`)
Contains all pastes, users, and SSH keys. **This is the most important volume to backup.**

Location on host: Managed by Docker (usually `/var/lib/docker/volumes/`)

### Cache Volume (`pasto-cache`)
Contains rendered HTML for performance.

Can be safely deleted - it will be regenerated.

### Sessions Volume (`pasto-sessions`)
Contains web session data.

Can be safely deleted - users will need to log in again.

### SSH Keys Volume (`pasto-ssh-keys`)
Contains server SSH host keys.

Should be preserved to avoid "host key changed" warnings.

## Managing the Container

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f pasto
docker compose logs -f pasto-ssh
```

### Stop Services

```bash
docker compose down
```

### Restart Services

```bash
docker compose restart
```

### Update to Latest Version

```bash
docker compose pull
docker compose up -d
```

### Access Container Shell

```bash
docker compose exec pasto /bin/sh
```

## Production Considerations

### Persistent Storage

Ensure you backup the `pasto-data` volume regularly:

```bash
# Backup
docker run --rm -v pasto-data:/data -v $(pwd):/backup alpine tar czf /backup/pasto-backup-$(date +%Y%m%d).tar.gz /data

# Restore
docker run --rm -v pasto-data:/data -v $(pwd):/backup alpine tar xzf /backup/pasto-backup-20250126.tar.gz -C /
```

### Resource Limits

Add resource limits to `docker-compose.yml`:

```yaml
services:
  pasto:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

### Reverse Proxy

Use Traefik, Nginx, or Caddy for SSL termination:

**Example with Caddy:**

```
paste.example.com {
    reverse_proxy localhost:3000
}

ssh.example.com {
    reverse_proxy localhost:2222
}
```

### Health Checks

```bash
# Check if web server is up
curl http://localhost:3000

# Check if SSH server is up
nc -zv localhost 2222
```

## Troubleshooting

### Port Already in Use

If ports 3000 or 2222 are already in use:

```yaml
services:
  pasto:
    ports:
      - "8080:3000"  # Use port 8080 instead

  pasto-ssh:
    ports:
      - "2223:2222"  # Use port 2223 instead
```

### Permission Issues

Ensure the container has write permissions to volumes:

```yaml
services:
  pasto:
    user: "1000:1000"  # Use your UID:GID
```

### Logs Location

Logs are output to stdout/stderr and can be viewed with:

```bash
docker compose logs -f
```

## Next Steps

- [Configuration Guide](../installation/configuration.md)
- [Web Interface](../user-guide/web-interface.md)
- [SSH Access](../user-guide/ssh-access.md)
- [Production Deployment](../deployment/production.md)
