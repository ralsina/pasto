#!/bin/bash
# Build script for Pasto that loads environment variables

# Load .env file if it exists
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# Build all binaries
echo "Building Pasto binaries..."
shards build pasto pasto-ssh pasto-backup pasto-crypto pasto-cli

# Compress assets
echo ""
echo "Compressing assets..."
./compress_assets.sh

echo ""
echo "✓ Build complete!"
echo "Binaries: bin/pasto, bin/pasto-ssh, bin/pasto-backup, bin/pasto-crypto, bin/pasto-cli"

