#!/bin/bash
# Convert SVG icon to Windows ICO format
# Requires: imagemagick (sudo apt install imagemagick)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG_FILE="$SCRIPT_DIR/resources/icons/app_icon.svg"
ICO_FILE="$SCRIPT_DIR/resources/app_icon.ico"
PNG_DIR="$SCRIPT_DIR/resources/icons"

echo "Converting SVG to ICO..."

# Create PNG files at various sizes needed for ICO
for size in 16 24 32 48 64 128 256; do
    echo "  Creating ${size}x${size} PNG..."
    convert -background none -resize ${size}x${size} "$SVG_FILE" "$PNG_DIR/icon_${size}.png"
done

# Combine all PNGs into a single ICO file
echo "Creating ICO file..."
convert "$PNG_DIR/icon_16.png" \
        "$PNG_DIR/icon_24.png" \
        "$PNG_DIR/icon_32.png" \
        "$PNG_DIR/icon_48.png" \
        "$PNG_DIR/icon_64.png" \
        "$PNG_DIR/icon_128.png" \
        "$PNG_DIR/icon_256.png" \
        "$ICO_FILE"

echo "Done! Created: $ICO_FILE"

# Clean up intermediate PNGs (optional - comment out to keep them)
# rm "$PNG_DIR"/icon_*.png

echo ""
echo "Icon sizes included in ICO:"
identify "$ICO_FILE"
