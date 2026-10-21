# Independent native preview review

Status: one independent static review completed against `5da350b..2d9a982`.
The reviewer ran no applications, builds, tests, or desktop automation on the user's Mac.
The review did not approve merging.
The executor fixed all six findings and added regression coverage.
[RESULTS.md](RESULTS.md) records the latest runtime gate and its limits.
No second independent review or upstream pull request occurred.

## Findings and corrections

| Finding | Correction | Regression evidence |
| --- | --- | --- |
| Nested device type conflict could delete unrelated directory contents. | Preflight the entire upload and reject observed file/folder conflicts before calling the engine. | `TransferSafetyTests.testFolderUploadCannotReplaceNestedDeviceDirectoryWithFile` |
| Storage selection could expose the previous destination during a switch. | Require a loaded destination matching the selected storage and retain the prior selection after failure. | `StorageAndUSBTests.testStorageSwitchCannotCopyToPreviousStorage` |
| Device names could alias on the Mac destination volume. | Reserve names exclusively on that volume before downloading and validate staged file types and sizes. | `TransferSafetyTests.testFolderDownloadRejectsNamesThatAliasOnTheDestinationVolume` |
| An unrelated USB detach could invalidate the active phone. | Match registry identity and decoded vendor, product, and serial metadata to the connected phone. | `StorageAndUSBTests.testUnrelatedUSBDetachPreservesActivePhoneAndLease` |
| An empty device folder could produce no output. | Create the owned staging tree before downloading. | `TransferSafetyTests.testEmptyDeviceFolderDownloadProducesItsPromisedDirectory` |
| The disconnected UI test selected the title instead of its explanation. | Select the explanation by its accessibility identifier. | `TransferInteractionTests.testDisconnectedDeviceCannotStartCopy` |

The reviewer graded the first five findings Important and the selector finding Minor.
The executor promoted the selector finding because it blocked the complete runtime gate.
No established Critical finding or deferred Minor finding remains in this review record.
Hardware and accessibility limits below remain unverified acceptance items.

## Additional safety corrections

Queued operations now check session validity before entering the engine and after returning.
The queued-deletion regression verifies that invalidated work cannot delete its disposable fixture.

File promises now fail on destination collisions without requesting a sheet.
The regression completes without a window and preserves existing destination bytes.
Ordinary browser transfers retain Replace, Skip, and Stop choices.
USB metadata decoding has separate regression coverage.

The engine's source and checked-in binaries remain unchanged.
Packaging signs copied libraries inside the preview bundle.
The regression transports reproduce engine behavior at its boundary.
They do not establish physical-phone behavior.

## RED and GREEN evidence

[Run 39678995417](https://github.com/unhingedpanda/openmtp/actions/runs/39678995417), source `4aa60b9`, reported 12 failures across 41 unit tests.
It reproduced nested deletion, wrong storage state, unrelated USB invalidation, case-name collapse, and missing empty-folder output.

[Run 39679870083](https://github.com/unhingedpanda/openmtp/actions/runs/39679870083), source `344e6ee`, reported 16 failures across 44 tests.
Additional failures covered stale queued deletion, a promised-export collision without a window, and missing USB identity decoding.
The executor preserved unit feedback before cancelling the superseded batch.

After `c5f4dc4`, [macOS 26 run 39680291750](https://github.com/unhingedpanda/openmtp/actions/runs/39680291750) passed all 44 unit tests.
[macOS 27 run 39680295979](https://github.com/unhingedpanda/openmtp/actions/runs/39680295979) also passed all 44.
Both environments passed these tests again at `f668ffd` and `78ac249`.
All eight added safety regressions passed.
The final complete gates each passed 50 tests, including the added resize regression.
The earlier missing-window and performance-harness failures remained separate runtime gates until diagnosed.

## Disposition of matters the reviewer declined to judge

| Matter | Disposition and limit |
| --- | --- |
| Focus after swaps, header clicks, and grid context clicks | Runtime coverage verifies browser swaps and disconnected-pane focus without deleting the selected local file. Full grid context interaction remains unverified. |
| Finder export after source-window closure | A real NSWindow closure and retained provider delegate pass the component test. A physical Finder receiver and phone remain unverified. |
| Promise collisions after closure | The no-window collision regression passes and preserves existing bytes. A real Finder lifecycle check remains unverified. |
| Rapid reconnects and queued destructive calls | The queued-deletion regression prevents transport-side fixture deletion. Physical reconnect timing remains unverified. |
| Callback concurrency | Foreign-return and callback-string lifetime fixtures pass. Source inspection supports serialized operations. Real phone concurrency remains unverified. |
| Missing-window and allocator-abort causes | A synchronous test exposed an invalid `moveDown:` call. The corrected harness uses Down Arrow events. A minimal SwiftUI control reproduced the combined test-argument startup failure. Environment-based fixtures restore normal launches. |
| Appearance, accessibility, and performance | Light/dark captures and component/process measurements are recorded in RESULTS.md. VoiceOver and system accessibility-setting transitions remain unverified. |
| Phone integrity, throughput, storage-full behavior, and partial writes | Deferred to an explicitly authorized disposable-phone session. No physical-phone acceptance is claimed. |
| Binary distribution provenance and notarization | Local preview signing is verified. Dependency provenance gaps remain in THIRD_PARTY_NOTICES.md. No application binary release occurred. |
| Intel and older macOS | Outside the approved arm64 macOS 26+ preview boundary. |

Ruling: retain these explicit hardware and accessibility limits instead of treating fixture coverage as physical acceptance.
The user authorized remote verification and kept desktop automation on their Mac disabled.
The executor did not replace that boundary with local UI tests.
