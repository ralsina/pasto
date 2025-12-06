#!/usr/bin/env bash
# compress_new_assets.sh: Compress new JavaScript assets with brotli and gzip
# This script handles only the compression for our new editor files

set -e

ASSETS_DIR="src/baked/assets"

# Function to compress with both formats
compress_asset() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "Compressing $(basename "$file")..."
        local original_size=$(wc -c < "$file")
        local brotli_size=0
        local gzip_size=0

        # Compress with brotli
        if command -v brotli >/dev/null 2>&1; then
            if brotli -f "$file" -o "${file}.br"; then
                brotli_size=$(wc -c < "${file}.br")
                local brotli_ratio=$(echo "scale=1; $brotli_size * 100 / $original_size" | bc -l 2>/dev/null || echo "N/A")
                echo "  brotli: ${original_size} bytes -> ${brotli_size} bytes (${brotli_ratio}% of original)"
            else
                echo "  brotli: compression failed"
            fi
        else
            echo "  brotli: command not found, skipping"
        fi

        # Compress with gzip
        if gzip -c "$file" > "${file}.gz"; then
            gzip_size=$(wc -c < "${file}.gz")
            local gzip_ratio=$(echo "scale=1; $gzip_size * 100 / $original_size" | bc -l 2>/dev/null || echo "N/A")
            echo "  gzip:  ${original_size} bytes -> ${gzip_size} bytes (${gzip_ratio}% of original)"
        else
            echo "  gzip: compression failed"
        fi

        echo "  ---"
    fi
}

echo "Compressing new JavaScript assets..."

# Compress our new JavaScript files
compress_asset "$ASSETS_DIR/editor-shared.js"
compress_asset "$ASSETS_DIR/mobile-controls.js"

echo "New asset compression completed!"