#!/bin/bash
set -e

docker run --rm --privileged \
  multiarch/qemu-user-static \
  --reset -p yes

# Build for AMD64
docker build . -f Dockerfile.static -t pasto-builder
docker run -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto"
docker run -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-ssh"
docker run -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-crypto"
docker run -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-backup"
docker run -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-cli"
mv bin/pasto bin/pasto-static-linux-amd64
mv bin/pasto-ssh bin/pasto-ssh-static-linux-amd64
mv bin/pasto-crypto bin/pasto-crypto-static-linux-amd64
mv bin/pasto-backup bin/pasto-backup-static-linux-amd64
mv bin/pasto-cli bin/pasto-cli-static-linux-amd64

# Build for ARM64
docker build . --platform linux/arm64 -f Dockerfile.static -t pasto-builder
docker run --platform linux/arm64 -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto"
docker run --platform linux/arm64 -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-ssh"
docker run --platform linux/arm64 -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-crypto"
docker run --platform linux/arm64 -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-backup"
docker run --platform linux/arm64 -ti --rm -v "$PWD":/app --user="$UID" pasto-builder /bin/sh -c "cd /app && rm -rf lib shard.lock && shards build --release --without-development --static -Dpreview_mt -Dinotify --link-flags '-lssh -lssl -lcrypto' pasto-cli"
mv bin/pasto bin/pasto-static-linux-arm64
mv bin/pasto-ssh bin/pasto-ssh-static-linux-arm64
mv bin/pasto-crypto bin/pasto-crypto-static-linux-arm64
mv bin/pasto-backup bin/pasto-backup-static-linux-arm64
mv bin/pasto-cli bin/pasto-cli-static-linux-arm64
