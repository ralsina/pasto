#!/bin/bash
set -e

# Retry function with exponential backoff
retry_command() {
    local max_attempts=3
    local attempt=1
    local command="$1"
    local description="$2"

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts: $description"
        if eval "$command"; then
            echo "Success: $description"
            return 0
        else
            exit_code=$?
            if [ $attempt -eq $max_attempts ]; then
                echo "Failed after $max_attempts attempts: $description"
                return $exit_code
            else
                wait_time=$((attempt * 5))
                echo "Failed with exit code $exit_code, retrying in ${wait_time}s..."
                sleep $wait_time
            fi
        fi
        attempt=$((attempt + 1))
    done
}

docker run --rm --privileged \
  multiarch/qemu-user-static \
  --reset -p yes

# Build for AMD64
echo "Building Docker image for AMD64..."
retry_command "docker build . -f Dockerfile.static -t pasto-builder" "Build AMD64 builder image"

echo "Building pasto for AMD64..."
retry_command "docker run -ti --rm -v \"$PWD\":/app --user=\"$UID\" pasto-builder /bin/sh -c \"cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto\"" "Build pasto (AMD64)"

retry_command "docker run -ti --rm -v \"$PWD\":/app --user=\"$UID\" pasto-builder /bin/sh -c \"cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-ssh\"" "Build pasto-ssh (AMD64)"

retry_command "docker run -ti --rm -v \"$PWD\":/app --user=\"$UID\" pasto-builder /bin/sh -c \"cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-crypto\"" "Build pasto-crypto (AMD64)"

retry_command "docker run -ti --rm -v \"$PWD\":/app --user=\"$UID\" pasto-builder /bin/sh -c \"cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-backup\"" "Build pasto-backup (AMD64)"

retry_command "docker run -ti --rm -v \"$PWD\":/app --user=\"$UID\" pasto-builder /bin/sh -c \"cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-cli\"" "Build pasto-cli (AMD64)"

mv bin/pasto bin/pasto-static-linux-amd64
mv bin/pasto-ssh bin/pasto-ssh-static-linux-amd64
mv bin/pasto-crypto bin/pasto-crypto-static-linux-amd64
mv bin/pasto-backup bin/pasto-backup-static-linux-amd64
mv bin/pasto-cli bin/pasto-cli-static-linux-amd64

# Build for ARM64
echo "Building Docker image for ARM64..."
retry_command "docker build . --platform linux/arm64 -f Dockerfile.static -t pasto-builder" "Build ARM64 builder image"

echo "Building pasto for ARM64..."
retry_command "docker run --platform linux/arm64 -ti --rm -v \"$PWD\":/app --user=\"$UID\" pasto-builder /bin/sh -c \"cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto\"" "Build pasto (ARM64)"

retry_command "docker run --platform linux/arm64 -ti --rm -v \"$PWD\":/app --user=\"$UID\" pasto-builder /bin/sh -c \"cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-ssh\"" "Build pasto-ssh (ARM64)"

retry_command "docker run --platform linux/arm64 -ti --rm -v \"$PWD\":/app --user=\"$UID\" pasto-builder /bin/sh -c \"cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-crypto\"" "Build pasto-crypto (ARM64)"

retry_command "docker run --platform linux/arm64 -ti --rm -v \"$PWD\":/app --user=\"$UID\" pasto-builder /bin/sh -c \"cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-backup\"" "Build pasto-backup (ARM64)"

retry_command "docker run --platform linux/arm64 -ti --rm -v \"$PWD\":/app --user=\"$UID\" pasto-builder /bin/sh -c \"cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-cli\"" "Build pasto-cli (ARM64)"

mv bin/pasto bin/pasto-static-linux-arm64
mv bin/pasto-ssh bin/pasto-ssh-static-linux-arm64
mv bin/pasto-crypto bin/pasto-crypto-static-linux-arm64
mv bin/pasto-backup bin/pasto-backup-static-linux-arm64
mv bin/pasto-cli bin/pasto-cli-static-linux-arm64
