# Independent native preview review

Status: one independent static review completed against `5da350b..2d9a982`.
The reviewer ran no applications, builds, tests, or desktop automation on the user's Mac.
The review did not approve merging.
Remediation and remote runtime verification remain in progress.

## Findings

| Finding | Effect | Correction prepared |
| --- | --- | --- |
| Nested device type conflict | Uploading a file over a nested directory can delete unrelated contents. | Preflight the entire upload before calling the unchanged engine. |
| Storage selection race | Copying during a slow storage switch can target the previous storage. | Require a loaded destination matching the picker and retain the prior selection after failure. |
| Destination name aliases | Case-distinct device files can collapse on a case-insensitive Mac volume. | Reserve every destination name exclusively on the actual destination volume before downloading. |
| Unrelated USB detach | Removing an accessory can invalidate an active phone transfer. | Match notification registry identity to the connected phone. |
| Empty folder download | The unchanged engine creates no root for an empty directory. | Create the owned staging tree before downloading and validate the resulting files. |
| Disconnected UI selector | The test searches the title for text belonging to the explanation. | Use the explanation's accessibility identifier. |

The reviewer graded the first five findings Important and the selector finding Minor.
The executor promoted the selector finding because it blocks the full runtime verification gate.
No established Critical finding or deferred Minor finding remains in this review record.

## Additional safety checks

The executor added checks for queued destructive calls after invalidation and promised-export collisions without an approval window.
Queued requests need validation before entering the engine, as well as after returning.
File promises need a collision error when no approval window exists.
Ordinary browser transfers retain their collision choices.

The new tests preserve disposable files when verifying rejected operations.
They do not establish physical-phone behavior.

## Evidence

[Remote run 39678995417](https://github.com/unhingedpanda/openmtp/actions/runs/39678995417) exercised source `4aa60b9` before the safety fixes.
Its 41 unit tests reported 12 failures across the five new regression cases.
The failures reproduced nested deletion, wrong storage state, unrelated USB invalidation, case-name collapse, and missing empty-folder output.
The earlier 36 non-performance unit tests passed in [run 39677470552](https://github.com/unhingedpanda/openmtp/actions/runs/39677470552).
Both runs failed the UI startup and measurement gates.

The regression fixtures reproduce engine behavior at the transport boundary.
The Go module source confirms that the existing engine recursively replaces matching device objects and creates local files by name.
The engine's source and binaries remain unchanged.

## Matters the reviewer declined to judge

1. Focus after pane swaps, header clicks, and grid context clicks lacked complete real-interaction coverage.
2. Real Finder export after source-window closure lacked a physical receiver and phone check.
3. Promise collisions after source-window closure lacked a real window-lifecycle check.
4. Rapid reconnects and queued destructive calls lacked proof of device-side effects.
5. Real callback concurrency lacked hardware evidence beyond the ownership fixture.
6. Missing-window startup and allocator-abort causes lacked sufficient runtime diagnostics.
7. Appearance, accessibility, responsiveness, and performance lacked completed captures and measurements.
8. Phone integrity, throughput, storage-full behavior, and partial writes lacked hardware evidence.
9. Public binary distribution retained dependency provenance and notarization gaps.
10. Intel and older macOS versions remained outside the approved preview boundary.

The executor will record the disposition of each matter with the final acceptance evidence.
These limits do not establish passing acceptance.
