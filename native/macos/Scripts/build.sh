#!/bin/bash
set -euo pipefail
native_dir="$(cd "$(dirname "$0")/.." && pwd)"
xcodegen generate --spec "$native_dir/project.yml"
xcodebuild build -project "$native_dir/OpenMTPNative.xcodeproj" -scheme OpenMTPNative -configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath "$native_dir/build/release" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
"$native_dir/Scripts/prepare-local-app.sh" "$native_dir/build/release/Build/Products/Release/OpenMTP Native.app"
