#!/usr/bin/env bash
# update_assets.sh: Download latest JS dependencies and concatenate into bundle.js
# Only bundle.js will be placed in src/baked/assets/

set -e
TMPDIR=$(mktemp -d)
LUCIDE_URL="https://unpkg.com/lucide@latest/dist/umd/lucide.min.js"
MARKED_URL="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.1/marked.min.js"
HIGHLIGHT_URL="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"
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
HIGHLIGHT_FILE="$TMPDIR/highlight.min.js"
CODEJAR_FILE="$TMPDIR/codejar.min.js"
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

# Download highlight.js
if ! curl -fsSL "$HIGHLIGHT_URL" -o "$HIGHLIGHT_FILE"; then
	echo "Error: Failed to download highlight.min.js from $HIGHLIGHT_URL" >&2
	rm -rf "$TMPDIR"
	exit 1
fi

# Concatenate into bundle.js (excluding CodeJar which will be a separate module)
echo "// lucide.min.js" > "$BUNDLE_FILE"
cat "$LUCIDE_FILE" >> "$BUNDLE_FILE"
echo -e "\n// marked.min.js" >> "$BUNDLE_FILE"
cat "$MARKED_FILE" >> "$BUNDLE_FILE"
echo -e "\n// highlight.min.js" >> "$BUNDLE_FILE"
cat "$HIGHLIGHT_FILE" >> "$BUNDLE_FILE"


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

# Download highlight.js CSS themes
HIGHLIGHT_THEMES=(
	"atom-one-dark.min.css"
	"atom-one-light.min.css"
)

for theme in "${HIGHLIGHT_THEMES[@]}"; do
	url="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/$theme"
	dest="src/baked/assets/$theme"
	echo "Downloading highlight.js theme: $theme ..."
	if ! curl -fsSL "$url" -o "$dest"; then
		echo "Error: Failed to download highlight.js theme $theme from $url" >&2
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
        echo "Compressing $(basename "$file")..."
        if command -v brotli >/dev/null 2>&1; then
            brotli --keep "$file" && \
            local original_size=$(wc -c < "$file") && \
            local compressed_size=$(wc -c < "${file}.br") && \
            local compression_ratio=$(echo "scale=1; $compressed_size * 100 / $original_size" | bc -l 2>/dev/null || echo "N/A") && \
            echo "  ${original_size} bytes -> ${compressed_size} bytes (${compression_ratio}% of original)"
        else
            echo "Warning: brotli command not found, skipping compression"
        fi
    fi
}

# Compress JavaScript files
compress_to_brotli "$ASSETS_DIR/bundle.js"
compress_to_brotli "$ASSETS_DIR/codejar.min.js"

# Compress CSS files
for css in "$ASSETS_DIR"/*.css; do
    compress_to_brotli "$css"
done

echo "Brotli compression completed for all assets"

# Clean up temp files
rm -rf "$TMPDIR"

echo "Assets updated and concatenated into $BUNDLE_FILE"