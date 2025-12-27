#!/bin/sh

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

pass github-registry | docker login ghcr.io -u ralsina --password-stdin
docker run --rm --privileged \
        multiarch/qemu-user-static \
        --reset -p yes
VERSION=$(shards version)

echo "Building Docker image for ARM64..."
retry_command "docker build . --platform=linux/arm64 --build-arg VERSION=\"${VERSION}\" --build-arg ARCH=arm64 -t ghcr.io/ralsina/pasto-arm64:latest -t ghcr.io/ralsina/pasto-arm64:\"${VERSION}\" --push" "Build and push ARM64 Docker image"

echo "Building Docker image for AMD64..."
retry_command "docker build . --platform=linux/amd64 --build-arg VERSION=\"${VERSION}\" --build-arg ARCH=amd64 -t ghcr.io/ralsina/pasto:latest -t ghcr.io/ralsina/pasto:\"${VERSION}\" --push" "Build and push AMD64 Docker image"
