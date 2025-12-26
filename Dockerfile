# Pasto Dockerfile
# Static build with minimal Alpine runtime

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
    gc-static \
    pcre2-dev \
    pcre2-static \
    yaml-dev \
    yaml-static \
    openssl-dev \
    openssl-libs-static \
    libxml2-dev \
    libxml2-static \
    zlib-dev \
    zlib-static \
    xz-dev \
    xz-static \
    libevent-dev \
    libevent-static \
    cmake \
    make \
    g++ \
    ca-certificates \
    tzdata

WORKDIR /app

RUN wget https://www.libssh.org/files/0.11/libssh-0.11.3.tar.xz
RUN tar -xf libssh-0.11.3.tar.xz && cd libssh-0.11.3 && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_STATIC_LIB=ON .. && \
    make && make install && cp src/libssh.a /usr/lib/libssh.a

# Copy dependency files first for better caching
COPY shard.yml shard.lock shard.override.yml ./

# Install dependencies
RUN shards install --production

# Copy source code
COPY src/ ./src/

# Build binaries in release mode
# -Dinotify: use inotify backend for file watching
RUN shards build --release -Dinotify --static --link-flags '-lssh -lssl -lcrypto' pasto pasto-ssh pasto-crypto pasto-backup pasto-cli

# Compress binaries with UPX for smaller image size
RUN apk add --no-cache upx && \
    upx --best --lzma /app/bin/pasto /app/bin/pasto-ssh /app/bin/pasto-crypto /app/bin/pasto-backup /app/bin/pasto-cli

# ============================================
# Stage 2: Minimal scratch runtime
# ============================================
FROM scratch

WORKDIR /app

# Copy CA certificates and timezone data from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy binaries
COPY --from=builder /app/bin/pasto /app/bin/pasto
COPY --from=builder /app/bin/pasto-ssh /app/bin/pasto-ssh
COPY --from=builder /app/bin/pasto-crypto /app/bin/pasto-crypto
COPY --from=builder /app/bin/pasto-backup /app/bin/pasto-backup
COPY --from=builder /app/bin/pasto-cli /app/bin/pasto-cli

# Create directories for persistent data (will be created as volumes)
VOLUME ["/app/data", "/app/public/cache", "/app/sessions"]

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

ENTRYPOINT ["/app/bin/pasto"]
