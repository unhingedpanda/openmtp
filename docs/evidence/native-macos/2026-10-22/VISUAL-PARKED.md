# Native visual refinement checkpoint

Done, with gaps: the visual work is saved, but inline rename still fails after switching list → icons → list.

Checked now on 2026-10-22 against Git, downloaded hosted results, native diagnostic traces, and the current source.
The user requested saving, committing, pushing, and parking this work for a later session.
No further development, tests, builds, or desktop automation ran while preparing this checkpoint.

## Resume here

Investigate why the inline rename editor ends immediately after the view-mode roundtrip.
Keep the expanded regression in `native/macos/UITests/BrowserInteractionTests.swift`.
Do not restart the visual redesign or remove the regression to obtain a pass.

Repository: `/Users/yash/Downloads/Code/products/openmtp-native`.
Branch: `codex/native-macos-ui`.
Push remote: `fork`, `https://github.com/unhingedpanda/openmtp.git`.
The `origin` remote belongs to upstream `ganeshrvel/openmtp`.
Do not push upstream, open a pull request, merge, or publish an app release.

## Objective and saved implementation

Keep the familiar two-pane OpenMTP workflow with a SwiftUI shell, AppKit file browsers, and the existing Kalam Go engine.
Target macOS 26 and later on Apple Silicon for this preview.
The accepted direction uses Apple-native controls and restrained Liquid Glass without a Rust engine rewrite.
The user rejected the initial preview and requested improvements across layout, materials, and file presentation.

| Commit | Saved work |
| --- | --- |
| `b2fac09943422496ef307f4f76b89c7ad29dd88c` | Balanced browser layout, native paths, Locations menu, labeled transfer action, larger actual file icons, connection state |
| `9077e0d2489699548e75aedd34c6039d58205e21` | Correct native view-picker accessibility selectors |
| `71059384ce46640a9759dce006d159b295868007` | Visible native divider, 140-point storage picker, connected appearance fixtures, expanded view-switch regression |
| `881e45c3bd2267588f4ffbe8bbdbb25171c872fc` | Debug-only keyboard and rename tracing for explicit hosted UI-test launches |

`DESIGN.md` and `.impeccable/design.json` preserve the native design rules and tokens.
The session ledger records a scoped visual review that resolved the divider and storage-width findings.
That review does not establish complete functional, physical-device, or manual accessibility acceptance.

## Current hosted results

Both completed diagnostic runs tested source `881e45c3bd2267588f4ffbe8bbdbb25171c872fc`.

| Environment | Run | Units | UI | Browser performance | Overall |
| --- | --- | --- | --- | --- | --- |
| macOS 26 | [39691999397](https://github.com/unhingedpanda/openmtp/actions/runs/39691999397) | 47 passed | 4 passed, 1 failed | 1 passed | Failed |
| macOS 27 | [39691999972](https://github.com/unhingedpanda/openmtp/actions/runs/39691999972) | 47 passed | 4 passed, 1 failed | 1 passed | Failed |

Both failures identify `BrowserInteractionTests/testKeyboardActionUsesTheFocusedPane()`.
The assertion says `Rename editor did not open. Status: 1 selected`.
The native traces provide more precise evidence than that assertion.

### What the trace proves

Both traces show Return reaching `BrowserTable` with one selected row and a valid rename callback.
`beginRename` sees three rows and a window.
The native field editor becomes the first responder, then editing ends with movement `0`.
The interval from editor creation to termination is approximately 236 milliseconds on macOS 26 and 320 milliseconds on macOS 27.
The root cause remains unknown.

macOS 27 excerpt:

```text
1466.4187205 table target=ObjectIdentifier(0x00000079e5714c00) key=36 renameCallback=true selected=1 indexes
1466.4188984583334 beginRename rows=3 selected=1 indexes window=true
1466.4532994166668 rename editor=true first=Optional(<NSTextView: 0x79e531a300>
1466.773220875 endRename movement=Optional(0)
```

Do not resume from the earlier hypothesis that Return never reaches the table or that rename never starts.
Fresh source inspection also confirms `FileTableView.updateNSView` already guards identical selections before calling `selectRowIndexes`.
`BrowserSplitView.updateNSView` still assigns each hosting view's root on every update.
Inspect editor lifetime, view updates, reloads, and focus changes before choosing a fix.
No causal explanation or functional fix has been established.

## Preserved evidence

[Checkpoint summary](visual-parked-881e45c/summary.json) records exact source, runs, counts, and diagnostic attachment provenance.
Each OS directory contains suite summaries, environment records, release measurements, bundle checks, and the native keyboard trace.
[SHA-256 manifest](visual-parked-881e45c/sha256.json) covers all checkpoint payload files.

`visual-parked-881e45c/captures-7105938/` contains nine named fixture captures per OS from source `7105938`.
These cover light and dark lists, icons, folders, selected icons, and a connected component at 400 × 600 points.
The connected component uses a long storage name and a mock device.
Its appearance does not establish real-phone connectivity.
The user's rejected personal screenshot remains local and ignored.

Raw downloads remain local under `.superpowers/sdd/2026-10-22-native-macos-ui/visual-v2-<run>/final/`.
Older successful evidence at `verified-78ac249/` remains historical and unchanged.
Its passing result does not validate the current expanded UI regression.

`collection-script.WIP.py.txt` preserves the unfinished evidence collector without executing it.
It still hardcodes source `7105938`, failed run IDs, and expected counts `47/5/1`.
It requires successful runs and will reject the current failed runs.
Update it only after a true final source passes both complete hosted gates.

## Local preview and boundaries

The newer local release bundle is `native/macos/build/visual-v2/Build/Products/Release/OpenMTP Native.app`.
Its product source is `7105938`, not the later diagnostic revision.
The saved bundle report records 5.424 MiB, valid local signatures, and no quarantine attribute.
Those checks do not establish notarization or public distribution readiness.
The diagnostic source compiled earlier through build-for-testing without launching local tests.

Process readback during parking found the user's older `final-bca90b9` preview running as PID `38060`.
Codex left that app running and found no local xcodebuild, xctest, or XCTRunner process.
Do not quit, replace, or relaunch the app without a new user instruction.

No local desktop automation, local tests, benchmarks, screenshots, mouse control, or keyboard control are authorized.
Use headless builds and bundle verification locally when development resumes.
Run tests and captures on standard hosted macOS 26 and `xcode-27` runners in the public fork.
Do not enable paid runners or move these jobs to a private repository.
Leave the installed Electron OpenMTP app and unrelated files untouched.

Physical-phone transfers, checksums, reconnects, throughput, live glass behavior, VoiceOver, and manual accessibility remain unverified.

## Next session

1. Read this checkpoint and inspect current Git status before changing files.
2. Diagnose the premature editor termination using the preserved traces and current code.
3. Fix the cause while retaining the view-switch keyboard regression.
4. Run complete hosted verification on both approved macOS environments after implementation.
5. Rebuild, sign, and verify the final release without opening it locally.
6. Preserve evidence for the actual passing source and report remaining physical and manual gaps.

Original design: `docs/superpowers/specs/2026-10-22-native-macos-ui-design.md`.
Original plan: `docs/superpowers/plans/2026-10-22-native-macos-ui.md`.
Native build instructions: `native/macos/README.md`.
