#!/usr/bin/env bash
set -e

SOURCE_PNG="$1"
OUTPUT_ICNS="$2"

if [ -z "$SOURCE_PNG" ] || [ ! -f "$SOURCE_PNG" ]; then
    echo "Usage: $0 <source-png> <output-icns>"
    exit 1
fi

if [ -z "$OUTPUT_ICNS" ]; then
    OUTPUT_ICNS="AppIcon.icns"
fi

ICONSET="AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16     "$SOURCE_PNG" --out "$ICONSET/icon_16x16.png" > /dev/null
sips -z 32 32     "$SOURCE_PNG" --out "$ICONSET/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "$SOURCE_PNG" --out "$ICONSET/icon_32x32.png" > /dev/null
sips -z 64 64     "$SOURCE_PNG" --out "$ICONSET/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "$SOURCE_PNG" --out "$ICONSET/icon_128x128.png" > /dev/null
sips -z 256 256   "$SOURCE_PNG" --out "$ICONSET/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$SOURCE_PNG" --out "$ICONSET/icon_256x256.png" > /dev/null
sips -z 512 512   "$SOURCE_PNG" --out "$ICONSET/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$SOURCE_PNG" --out "$ICONSET/icon_512x512.png" > /dev/null
sips -z 1024 1024 "$SOURCE_PNG" --out "$ICONSET/icon_512x512@2x.png" > /dev/null

iconutil -c icns "$ICONSET" -o "$OUTPUT_ICNS"
rm -rf "$ICONSET"

echo "Generated $OUTPUT_ICNS from $SOURCE_PNG"
