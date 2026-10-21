#!/bin/bash
set -euo pipefail
if [[ "${1:-}" != "--allow-desktop" && !( "${GITHUB_ACTIONS:-}" == "true" && "${RUNNER_ENVIRONMENT:-}" == "github-hosted" ) ]]; then
    echo 'Desktop tests are remote by default. Use the Native macOS verification workflow.' >&2
    echo 'Local desktop execution requires the explicit --allow-desktop option.' >&2
    exit 2
fi
native_dir="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$native_dir/Scripts/make-fixtures.py" /tmp/openmtp-native-fixtures
xcodegen generate --spec "$native_dir/project.yml"
xcodebuild test -project "$native_dir/OpenMTPNative.xcodeproj" -scheme OpenMTPNative -destination 'platform=macOS,arch=arm64' -derivedDataPath "$native_dir/build/verification" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
python3 "$native_dir/Scripts/verify-bundle.py" "$native_dir/build/release/Build/Products/Release/OpenMTP Native.app" --output "$native_dir/build/bundle-verification.json"
