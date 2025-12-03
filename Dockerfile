# Pasto Dockerfile
# Dynamic build with minimal Alpine runtime

# ============================================
# Stage 1: Build the Crystal application
# ============================================
FROM alpine:edge AS builder

# Install Crystal and build dependencies
RUN apk add --no-cache \
    crystal \
    shards \
    git \
    gc-dev \
    pcre2-dev \
    yaml-dev \
    openssl-dev \
    libxml2-dev \
    zlib-dev \
    xz-dev \
    libevent-dev \
    libssh-dev

WORKDIR /app

# Copy dependency files first for better caching
COPY shard.yml shard.lock shard.override.yml ./

# Install dependencies
RUN shards install --production

# Copy source code
COPY src/ ./src/

# Build both binaries in release mode
# -Dinotify: use inotify backend for file watching
RUN shards build --release -Dinotify

# Compress binaries with UPX for smaller image size
RUN apk add --no-cache upx && \
    upx --best --lzma /app/bin/pasto /app/bin/pasto-ssh

# ============================================
# Stage 2: Minimal Alpine runtime
# ============================================
FROM alpine:edge

WORKDIR /app

# Install only required runtime libraries
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    libgcc \
    gc \
    pcre2 \
    yaml \
    libevent \
    libssh \
    libxml2 \
    zlib \
    xz-libs

# Create non-root user
RUN addgroup -g 1000 pasto && \
    adduser -D -u 1000 -G pasto pasto

# Copy binaries
COPY --from=builder /app/bin/pasto /app/bin/pasto
COPY --from=builder /app/bin/pasto-ssh /app/bin/pasto-ssh

# Create directories for persistent data
RUN mkdir -p /app/data /app/public/cache /app/sessions && \
    chown -R pasto:pasto /app

USER pasto

# Expose ports
EXPOSE 3000 2222

# Environment variables
ENV PASTO_PORT=3000 \
    PASTO_BIND=0.0.0.0 \
    PASTO_STORAGE_DIR=/app/data \
    PASTO_CACHE_DIR=/app/public/cache \
    PASTO_SSH_ENABLED=true \
    PASTO_SSH_PORT=2222 \
    PASTO_SSH_BIND=0.0.0.0 \
    PASTO_ENV=production \
    TZ=UTC

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

ENTRYPOINT ["/app/bin/pasto"]
