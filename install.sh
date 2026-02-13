#!/bin/bash
set -e

BUILD_APP="/Users/brad/repo/ghostty/macos/build/ReleaseLocal/Ghostty.app"
INSTALL_APP="/Applications/Wightty.app"

echo "=== Wightty Install Script ==="

# Check build exists
if [ ! -d "$BUILD_APP" ]; then
    echo "ERROR: No build found at $BUILD_APP"
    echo "Run an Xcode ReleaseLocal build first."
    exit 1
fi

# Kill any running instances
echo "Killing Ghostty/Wightty processes..."
pkill -f "Ghostty.app" 2>/dev/null || true
pkill -f "Wightty.app" 2>/dev/null || true
sleep 1

# Remove old apps
echo "Removing /Applications/Ghostty.app..."
rm -rf /Applications/Ghostty.app

echo "Removing /Applications/Wightty.app..."
rm -rf /Applications/Wightty.app

# Copy fresh build
echo "Installing build to $INSTALL_APP..."
cp -R "$BUILD_APP" "$INSTALL_APP"

# Reset Launch Services to clear stale bundle ID mappings
echo "Resetting Launch Services database..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

echo "Launching Wightty..."
open "$INSTALL_APP"

echo "Done!"
