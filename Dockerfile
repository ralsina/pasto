# Pasto Dockerfile
# Multi-stage build for smaller final image

# ============================================
# Stage 1: Build the application
# ============================================
FROM crystallang/crystal:1.14-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
    yaml-dev \
    openssl-dev \
    zlib-dev \
    git

# Copy dependency files first for better caching
COPY shard.yml shard.lock ./

# Install dependencies
RUN shards install --production

# Copy source code
COPY src/ ./src/
COPY public/ ./public/

# Build both binaries in release mode with static linking
RUN shards build --release --static

# ============================================
# Stage 2: Runtime image
# ============================================
FROM alpine:3.19

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    libgcc \
    ca-certificates \
    tzdata

# Create non-root user for security
RUN addgroup -g 1000 pasto && \
    adduser -D -u 1000 -G pasto pasto

# Copy binaries from builder
COPY --from=builder /app/bin/pasto /app/bin/pasto
COPY --from=builder /app/bin/pasto-ssh /app/bin/pasto-ssh

# Copy public assets (CSS, JS, etc)
COPY --from=builder /app/public /app/public

# Create directories for persistent data
RUN mkdir -p /app/data /app/public/cache /app/sessions && \
    chown -R pasto:pasto /app

# Switch to non-root user
USER pasto

# Expose ports
# 3000 - HTTP server
# 2222 - SSH server
EXPOSE 3000 2222

# Default environment variables
ENV PASTO_PORT=3000 \
    PASTO_BIND=0.0.0.0 \
    PASTO_STORAGE_DIR=/app/data \
    PASTO_CACHE_DIR=/app/public/cache \
    PASTO_SSH_ENABLED=true \
    PASTO_SSH_PORT=2222 \
    PASTO_SSH_BIND=0.0.0.0 \
    PASTO_ENV=production

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Run the main Pasto server
# The SSH server runs as a separate process/container
CMD ["/app/bin/pasto"]
