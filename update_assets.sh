#!/usr/bin/env bash
# update_assets.sh: Download latest lucide.min.js and marked.min.js, concatenate into bundle.js
# Only bundle.js will be placed in src/baked/assets/

set -e
TMPDIR=$(mktemp -d)
LUCIDE_URL="https://unpkg.com/lucide@latest/dist/umd/lucide.min.js"
# Use CDNJS as fallback for marked.min.js
MARKED_URL="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.1/marked.min.js"
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

# Clean up temp files
rm -rf "$TMPDIR"

echo "Assets updated and concatenated into $BUNDLE_FILE"