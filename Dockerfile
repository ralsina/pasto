FROM alpine:3.23

WORKDIR /app

# Copy the pre-built static binaries for the target architecture
ARG TARGETARCH=amd64
COPY bin/pasto-static-linux-${TARGETARCH} /app/bin/pasto
COPY bin/pasto-ssh-static-linux-${TARGETARCH} /app/bin/pasto-ssh
COPY bin/pasto-backup-static-linux-${TARGETARCH} /app/bin/pasto-backup

# Compress binaries with UPX for smaller image size
RUN apk add --no-cache upx && \
    upx --best --lzma /app/bin/pasto /app/bin/pasto-ssh /app/bin/pasto-backup

# Copy CA certificates and timezone data
COPY --from=alpine:3.23 /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
RUN apk add --no-cache ca-certificates tzdata

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
