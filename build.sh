#!/bin/bash
# Build script for Pasto that loads environment variables

# Load .env file if it exists
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# Build all binaries
shards build pasto pasto-ssh pasto-backup pasto-crypto
