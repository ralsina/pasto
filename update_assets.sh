#!/usr/bin/env bash
# update_assets.sh: Download latest JS dependencies and concatenate into bundle.js
# Only bundle.js will be placed in src/baked/assets/

set -e
TMPDIR=$(mktemp -d)
LUCIDE_URL="https://unpkg.com/lucide@latest/dist/umd/lucide.min.js"
MARKED_URL="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.1/marked.min.js"
CODEJAR_URL="https://cdn.jsdelivr.net/npm/codejar@4.2.0/dist/codejar.min.js"
# Pico.css URLs
PICO_VERSION="2.1.1"
PICO_BASE="https://cdn.jsdelivr.net/npm/@picocss/pico@$PICO_VERSION/css"
PICO_FILES=(
	"pico.min.css"
	"pico.css"
	"pico.red.min.css"
	"pico.pink.min.css"
	"pico.fuchsia.min.css"
	"pico.purple.min.css"
	"pico.violet.min.css"
	"pico.indigo.min.css"
	"pico.blue.min.css"
	"pico.cyan.min.css"
	"pico.jade.min.css"
	"pico.green.min.css"
	"pico.lime.min.css"
	"pico.yellow.min.css"
	"pico.amber.min.css"
	"pico.pumpkin.min.css"
	"pico.orange.min.css"
	"pico.sand.min.css"
	"pico.grey.min.css"
	"pico.zinc.min.css"
	"pico.slate.min.css"
)
LUCIDE_FILE="$TMPDIR/lucide.min.js"
MARKED_FILE="$TMPDIR/marked.min.js"
BUNDLE_FILE="src/baked/assets/bundle.js"


# Download latest lucide.min.js
if ! curl -fsSL "$LUCIDE_URL" -o "$LUCIDE_FILE"; then
	echo "Error: Failed to download lucide.min.js from $LUCIDE_URL" >&2
	rm -rf "$TMPDIR"
	exit 1
fi

# Download latest marked.min.js
if ! curl -fsSL "$MARKED_URL" -o "$MARKED_FILE"; then
	echo "Error: Failed to download marked.min.js from $MARKED_URL" >&2
	rm -rf "$TMPDIR"
	exit 1
fi

# Concatenate into bundle.js (lucide + marked only, no highlight.js)
echo "// lucide.min.js" > "$BUNDLE_FILE"
cat "$LUCIDE_FILE" >> "$BUNDLE_FILE"
echo -e "\n// marked.min.js" >> "$BUNDLE_FILE"
cat "$MARKED_FILE" >> "$BUNDLE_FILE"


# Download all Pico.css files
for css in "${PICO_FILES[@]}"; do
	url="$PICO_BASE/$css"
	dest="src/baked/assets/$css"
	echo "Downloading $css ..."
	if ! curl -fsSL "$url" -o "$dest"; then
		echo "Error: Failed to download $css from $url" >&2
		rm -rf "$TMPDIR"
		exit 1
	fi
done

# Download CodeJar as separate ES module
CODEJAR_DEST="src/baked/assets/codejar.min.js"
echo "Downloading CodeJar ES module..."
if ! curl -fsSL "$CODEJAR_URL" -o "$CODEJAR_DEST"; then
	echo "Warning: Failed to download codejar.min.js from $CODEJAR_URL, will use CDN" >&2
	echo "CodeJar will be loaded from CDN as fallback"
fi

# Create brotli compressed versions of all assets for better performance
echo "Creating brotli compressed versions of assets..."
ASSETS_DIR="src/baked/assets"

# Function to create brotli compressed version
compress_to_brotli() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "Compressing $(basename "$file") with brotli..."
        if command -v brotli >/dev/null 2>&1; then
            brotli --keep "$file" && \
            local original_size=$(wc -c < "$file") && \
            local compressed_size=$(wc -c < "${file}.br") && \
            local compression_ratio=$(echo "scale=1; $compressed_size * 100 / $original_size" | bc -l 2>/dev/null || echo "N/A") && \
            echo "  ${original_size} bytes -> ${compressed_size} bytes (${compression_ratio}% of original)"
        else
            echo "Warning: brotli command not found, skipping brotli compression"
        fi
    fi
}

# Function to create gzip compressed version
compress_to_gzip() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "Compressing $(basename "$file") with gzip..."
        gzip -c "$file" > "${file}.gz" && \
        local original_size=$(wc -c < "$file") && \
        local compressed_size=$(wc -c < "${file}.gz") && \
        local compression_ratio=$(echo "scale=1; $compressed_size * 100 / $original_size" | bc -l 2>/dev/null || echo "N/A") && \
        echo "  ${original_size} bytes -> ${compressed_size} bytes (${compression_ratio}% of original)"
    fi
}

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

# Compress all uncompressed assets
echo "Compressing all assets in $ASSETS_DIR..."
for file in "$ASSETS_DIR"/*; do
    # Skip if file is already compressed
    if [[ "$file" == *.gz || "$file" == *.br ]]; then
        continue
    fi
    # Only compress regular files
    if [ -f "$file" ]; then
        compress_asset "$file"
    fi
done

echo "Asset compression completed (brotli + gzip) for all assets"

# Clean up temp files
rm -rf "$TMPDIR"

echo "Assets updated and concatenated into $BUNDLE_FILE"
