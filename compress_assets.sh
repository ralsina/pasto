#!/usr/bin/env bash
# compress_assets.sh: Compress all assets in src/baked/assets

ASSETS_DIR="src/baked/assets"

# Function to compress with both formats
compress_asset() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "Compressing $(basename "$file")..."
        local original_size=$(wc -c < "$file")

        # Compress with brotli
        if command -v brotli >/dev/null 2>&1; then
            if brotli -f "$file" -o "${file}.br"; then
                local brotli_size=$(wc -c < "${file}.br")
                echo "  brotli: ${original_size} bytes -> ${brotli_size} bytes"
            else
                echo "  brotli: compression failed"
            fi
        else
            echo "  brotli: command not found, skipping"
        fi

        # Compress with gzip
        if gzip -c -9 "$file" > "${file}.gz"; then
            local gzip_size=$(wc -c < "${file}.gz")
            echo "  gzip: ${original_size} bytes -> ${gzip_size} bytes"
        else
            echo "  gzip: compression failed"
        fi
    fi
}

echo "Compressing all assets..."

for file in "$ASSETS_DIR"/*; do
    # Skip .br and .gz files
    [[ "$file" == *.br ]] && continue
    [[ "$file" == *.gz ]] && continue

    # Compress the asset
    compress_asset "$file"
done

echo "Asset compression completed!"