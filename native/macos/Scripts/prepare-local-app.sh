#!/bin/bash
set -euo pipefail
app="${1:?Pass the locally built OpenMTP Native.app path}"
identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
if [[ "$identifier" != "dev.yash.openmtp.native" ]]; then
    echo "Refusing to modify a different application: $identifier" >&2
    exit 1
fi
# Scope quarantine removal to this locally built preview. Keep system policy intact.
/usr/bin/xattr -dr com.apple.quarantine "$app" 2>/dev/null || true
for library in "$app"/Contents/Resources/Engine/*.dylib; do
    /usr/bin/codesign --force --sign - "$library"
    /usr/bin/codesign --verify --strict "$library"
done
if [[ "${2:-}" != "--resources-only" ]]; then
    /usr/bin/codesign --force --sign - "$app"
    /usr/bin/codesign --verify --deep --strict "$app"
fi
if /usr/bin/xattr -lr "$app" | /usr/bin/grep -q com.apple.quarantine; then
    echo 'The local preview still has a quarantine attribute.' >&2
    exit 1
fi
