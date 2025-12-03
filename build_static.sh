#!/bin/bash
set -e

docker run --rm --privileged \
  multiarch/qemu-user-static \
  --reset -p yes

# Build for AMD64
docker build . -f Dockerfile.static -t pasto-builder
docker run -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --without-development --static -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto"
docker run -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --without-development --static --link-flags '-lssh -lssl -lcrypto' pasto-ssh"
mv bin/pasto bin/pasto-static-linux-amd64
mv bin/pasto-ssh bin/pasto-ssh-static-linux-amd64

# Build for ARM64
docker build . --platform linux/arm64 -f Dockerfile.static -t pasto-builder
docker run --platform linux/arm64 -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --without-development --static -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto"
docker run --platform linux/arm64 -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --without-development --static -Dno_watching --link-flags '-lssh -lssl -lcrypto' pasto-ssh"
mv bin/pasto bin/pasto-static-linux-arm64
mv bin/pasto-ssh bin/pasto-ssh-static-linux-arm64
