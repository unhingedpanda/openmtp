# Native preview acceptance

Status: implementation prepared. Remote final verification resumed at the user's explicit request.

The user stopped local automation, then authorized public-fork remote verification.
The agent terminated its XCUITest runner, preview process, and xcodebuild process.
A fresh process inventory confirmed that none remained.

## Remote verification

The public fork is [unhingedpanda/openmtp](https://github.com/unhingedpanda/openmtp/tree/codex/native-macos-ui).
The first remote batch is [run 39677470552](https://github.com/unhingedpanda/openmtp/actions/runs/39677470552).
Its results remain pending.
No desktop automation runs on the user's Mac during this batch.
Remote measurements describe the hosted Mac, not the user's Mac.

## Verified before the pause

- The native app and all test targets compiled.
- The release app built and passed local signature verification.
- The earlier complete gate passed 28 unit tests and one browser UI test.
- Manual native rename succeeded.
- The bundled engine reported the real no-device state.

## Interrupted final batch

The 10000-entry browser measurement harness crashed inside XCTest's asynchronous Swift error-observation wrapper.
It produced no performance result.
The runner restarted and continued other tests.
The browser keyboard, rename, folder creation, and pane-swap UI test passed.
The user stopped the batch before a complete final gate.
These partial results do not establish final acceptance.

## Still pending

- Diagnose the browser measurement harness.
- Complete the full final test gate.
- Measure launch, RSS, CPU, and browser response targets.
- Review final light/dark captures and accessibility behavior.
- Complete the independent whole-branch review.
- Validate device transfers, integrity, throughput, and device drag-and-drop.
- Validate macOS 26 runtime behavior.

Checked on this Mac before the pause: the USB inventory showed only a Generic Billboard Device.
No Android MTP test phone was present.
Before the pause, no push or public release occurred.
The user subsequently authorized publishing this branch to a public fork for remote testing.
The installed OpenMTP remains separate.
