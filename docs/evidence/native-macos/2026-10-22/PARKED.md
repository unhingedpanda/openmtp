# Native OpenMTP checkpoint

Status: remote verification resumed on 2026-10-22 at the user's request.
Desktop automation on the user's Mac remains paused.
See [REMOTE.md](REMOTE.md) for the authorized remote execution boundary.
The following record preserves the original parking checkpoint.
Saving this checkpoint did not run tests or launch the app.

## Saved implementation

- Checkout: `/Users/yash/Downloads/Code/products/openmtp-native`.
- Branch: `codex/native-macos-ui`.
- Implementation commit: `0645721`.
- Base upstream commit: `5da350b69c6d0d4aed67a063498ee89c7448400a`.
- Code: `native/macos/`.
- Design: `docs/superpowers/specs/2026-10-22-native-macos-ui-design.md`.
- Plan: `docs/superpowers/plans/2026-10-22-native-macos-ui.md`.

The implementation includes a SwiftUI shell, native AppKit browser controls, file actions, transfer queue, collision handling, and drag-and-drop support.
The existing Kalam Go engine remains in place.
The preview has its own application identifier, `dev.yash.openmtp.native`.
Local signing and quarantine preparation apply to the preview bundle.
The installed OpenMTP remains separate.
No push, public release, or upstream pull request occurred.

## Acceptance limits

The last complete gate passed 28 unit tests and one browser UI test before later changes.
The source log is `.superpowers/sdd/2026-10-22-native-macos-ui/task4-final.log`.
The later final batch stopped before completion.
Its source log is `.superpowers/sdd/2026-10-22-native-macos-ui/final-tests.log`.
Do not report final acceptance as passing.

The browser performance harness crashed with `freed pointer was not the last allocation`.
The crash stack includes XCTest's asynchronous Swift error-observation wrapper.
This evidence does not identify the root cause.
The harness produced no browser performance JSON.
The runner restarted, and other tests continued before the user stopped the batch.

Pending work:

- Investigate the browser measurement harness.
- Complete the final test gate after explicit authorization.
- Measure launch time, RSS, CPU, and browser response.
- Review final appearance captures and accessibility behavior.
- Complete the independent whole-branch review.
- Validate transfers, integrity, throughput, and device drag-and-drop with a physical phone.
- Validate macOS 26 runtime behavior.

See [RESULTS.md](RESULTS.md) for the acceptance record.
Tasks 5 and 6 have committed implementations but incomplete final gates.

## Preserved local evidence

These paths remain in this checkout and are intentionally ignored by Git:

- Execution ledger, task briefs, and raw logs: `.superpowers/sdd/2026-10-22-native-macos-ui/`.
- Research copied from `/tmp`: `.superpowers/sdd/2026-10-22-native-macos-ui/parked-archive/research/`.
- Ledger snapshot: `.superpowers/sdd/2026-10-22-native-macos-ui/parked-archive/execution-ledger-at-park.md`.
- Crash copy: `.superpowers/sdd/2026-10-22-native-macos-ui/parked-archive/xctest-2026-10-22-020914.ips`.
- File hashes and result-directory inventory: `.superpowers/sdd/2026-10-22-native-macos-ui/parked-archive/manifest.json`.
- Prior signed builds and test results: `native/macos/build/signed/`.
- Release preview: `native/macos/build/release/Build/Products/Release/OpenMTP Native.app`.
- Interrupted final results: `native/macos/build/verification/Logs/Test/`.

The research archive preserves all 15 source files, including measurements, research notes, source code, and downloaded reference artifacts.
The archive copy matched the source hashes when saved.
Earlier OpenMTP measurements and future native measurements use different workloads unless explicitly normalized.
Do not infer a measured native speedup from bundle sizes or unmatched measurements.

## Proposed testing separation

This separation is a proposal, not an implemented test configuration.

The existing `verify.sh` runs both unit and UI targets through the `OpenMTPNative` scheme.
The current unit target also includes AppKit window and component-performance tests.
Selecting that target alone does not establish a desktop-free test run.
Do not run the combined script for background-only testing.

On an authorized resume:

1. Read the user's current authorization before executing tests.
2. Separate pure logic, bridge, filesystem, and queue tests from window tests.
3. Run desktop UI tests in an isolated macOS VM or on a separate Mac.
4. Reserve physical USB acceptance for a short, explicitly authorized hardware session.
5. Investigate the harness crash before claiming a valid performance result.
6. Update acceptance evidence without replacing the interrupted run's original logs.

A local VM isolates the desktop but still consumes this Mac's CPU and memory.
A remote Mac can move both desktop activity and test execution away from this Mac.
Neither alternative has been configured for this project.
