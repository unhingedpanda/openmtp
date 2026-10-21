# OpenMTP Native preview

A separate arm64 macOS 26+ preview with a SwiftUI shell, AppKit file views, and the existing Kalam engine.
The installed `/Applications/OpenMTP.app` stays unchanged.
Physical-device acceptance remains pending.
Remote macOS 26 and 27 runtime verification runs in the fork's GitHub Actions workflow.

## Build and open

Install Xcode and XcodeGen before building.
Run from the repository root:

```sh
native/macos/Scripts/build.sh
open 'native/macos/build/release/Build/Products/Release/OpenMTP Native.app'
```

The build copies the existing engine pair, prepares only the preview bundle, and applies local ad-hoc signatures.
The preparation script removes a quarantine attribute only from the built preview.
It verifies the app and both libraries.
It does not change Gatekeeper or other system security settings.
This is local signing, not a notarized public release.

## Workflow

Browse local files and a connected device in native list or grid views.
Choose internal storage or SD storage when the engine reports them.
Use the toolbar to create a folder or copy selected items to the other pane.
Press Return to rename one selected item.
Use Command-Up to navigate upward and Command-R to refresh.
Use Command-Delete to move local files to Trash or request permanent device deletion.
The View menu changes pane order and hidden-file visibility.

Drag local files from Finder into a pane to copy them to its current location.
Drag device files to the Mac pane or Finder to download them.
Finder exports retain their file-promise writer until completion.
The app rejects references from an earlier device connection.

Browser copies ask Replace, Skip, or Stop when a destination exists.
Finder exports report a collision error instead of waiting for an approval window.
Device-folder replacement updates matching files and retains other files in that folder.
File/folder conflicts stop the upload before the engine runs.
Local downloads stage their output before replacement.
Device transfer failures may leave partial copies.
The engine has no immediate cancellation entry point.
“Stop after current item” finishes the current file or complete folder before stopping queued work.
Closing or quitting during a transfer requires a decision.

## Verification

Desktop automation runs on the public fork's standard GitHub-hosted macOS runner:

```sh
gh workflow run native-macos.yml -R unhingedpanda/openmtp --ref codex/native-macos-ui
gh run list -R unhingedpanda/openmtp --workflow native-macos.yml
```

The workflow builds the preview, checks its bundle, runs tests, and records measurements.
It preserves evidence for three days.
The workflow skips private repositories to avoid consuming private-repository minutes.
It restricts runner selection to the two standard hosted labels.
Remote timings describe the hosted Mac and do not establish performance on another Mac.

Local desktop execution requires an explicit option:

```sh
native/macos/Scripts/verify.sh --allow-desktop
python3 native/macos/Scripts/make-fixtures.py /tmp/openmtp-native-fixtures
python3 native/macos/Scripts/benchmark.py \
  'native/macos/build/release/Build/Products/Release/OpenMTP Native.app' \
  /tmp/openmtp-native-fixtures/1000 \
  --output native/macos/build/benchmark.json --allow-desktop
```

The test suite uses disposable files and an explicit test defaults suite.
Test-only fixture, appearance, and narrow-window settings use environment variables.
The initial window must open without a New Window command.
It does not simulate a connected phone in the real application.
The component performance test records 100 AppKit actions against 10000 real local fixture files.
Its hidden-window timing does not measure physical input-to-screen latency.
The process benchmark records ten warm first-window launches, summed RSS after 30 seconds, and CPU over 30 seconds.

Results and remaining limits: [native preview acceptance](../../docs/evidence/native-macos/2026-10-22/RESULTS.md).
Hardware checks must use disposable phone folders and round-trip SHA-256 checksums.
Throughput comparisons require the same phone, cable, files, and timing method.

See `THIRD_PARTY_NOTICES.md` and the bundled license files for source attribution.
