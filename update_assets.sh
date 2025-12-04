#!/usr/bin/env bash
# update_assets.sh: Download latest lucide.min.js and marked.min.js, concatenate into bundle.js
# Only bundle.js will be placed in src/baked/assets/

set -e
TMPDIR=$(mktemp -d)
LUCIDE_URL="https://unpkg.com/lucide@latest/dist/umd/lucide.min.js"
MARKED_URL="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.1/marked.min.js"
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

# Concatenate into bundle.js
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

# Clean up temp files
rm -rf "$TMPDIR"

echo "Assets updated and concatenated into $BUNDLE_FILE"