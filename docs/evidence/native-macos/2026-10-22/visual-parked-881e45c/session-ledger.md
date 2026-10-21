# Visual refinement progress

User rejected the original native app screenshot and invoked Impeccable, UI/UX Pro Max, and Frontend Design.
User chose all three concerns: layout, materials, and file grid.
Keep the approved Apple-native, Liquid Glass, two-pane workflow. No local desktop automation or app relaunch.
Only headless builds and bundle verification ran locally. All tests and UI captures run on standard public-fork hosted Macs.

## Saved source

- b2fac09943422496ef307f4f76b89c7ad29dd88c: pane layout, native paths, toolbar Locations menu, larger actual file icons.
- 9077e0d2489699548e75aedd34c6039d58205e21: macOS picker test selectors use radio groups instead of segmented controls.
- 71059384ce46640a9759dce006d159b295868007: restore native divider, cap storage picker at 140 points, connected fixture captures.
- 881e45c3bd2267588f4ffbe8bbdbb25171c872fc: debug-only explicit UI-test keyboard tracing, investigating rename after list/icon roundtrip.

Branch codex/native-macos-ui, pushed only to fork unhingedpanda/openmtp. No upstream PR or app binary release.
DESIGN.md updates and .impeccable/design.json are included in the parking commit.

## Current blocker

Both OSes at 7105938 passed 47 unit tests and 1 browser performance test. Four of five UI tests passed.
The expanded keyboard UI case switches list -> icons -> list, then clicks a row, presses Down and Return.
Return does not expose the rename editor. AX reports the table keyboard-focused and one selected file.
Direct table.click() initially failed on blank table space. It was corrected to table.cells.firstMatch.click().
The original keyboard case without the mode roundtrip had previously passed.
Do not remove the new regression to get green. Diagnose why the field editor ends immediately.

## Diagnostic runs completed with the same UI failure

Source 881e45c:
- macOS 26: 39691999397
- macOS 27: 39691999972

NativeUITestDiagnostics in Core/LaunchConfiguration.swift runs only with DEBUG, OPENMTP_UI_TESTING=1,
and OPENMTP_UI_DIAGNOSTICS pointing at the owned test log. Release is inactive.
WindowMarker adds a non-consuming local key event monitor only for that diagnostic launch.
BrowserTable logs key events. Coordinator.beginRename logs rows, selection, window, and editor presence.
UITest attaches the log as Native-keyboard-diagnostics.txt in its defer.
Download final native-macos-{macos-26|xcode-27}-{run}-1 artifacts. Parse ui-attachments/manifest.json for that text file.
The log distinguishes wrong first responder, a missing coordinator/table, or an editor that immediately closes.
Both runs completed: 47 units passed, 4 UI passed, 1 UI failed, and 1 browser performance test passed per OS.
Both traces prove Return reaches BrowserTable and begins rename with a valid field editor.
The editor ends with movement 0 after about 236 ms on macOS 26 and 320 ms on macOS 27.
Earlier event-routing and missing-editor hypotheses are superseded by this trace.
Fresh source inspection confirms identical-selection updates already guard selectRowIndexes.
BrowserSplitView.updateNSView still reassigns host.rootView on every update. This is an investigation lead, not a proven cause.
No causal fix has been applied. The canonical parked checkpoint is docs/evidence/native-macos/2026-10-22/VISUAL-PARKED.md.

## Visual review completed

Read-only fresh agent impeccable_finish_reviewer examined user screenshot and current captures.
First full review b2fac09: only material fix was hidden native divider. Storage width needed a connected fixture.
Final scoped verdict at 7105938: both divider and constrained storage fixes RESOLVED on both OSes and appearances.
No additional visual correction required. Do not reopen polish. Keyboard remains a separate functional blocker.
It does not establish physical phone acceptance, manual VoiceOver, divider dragging, or live Liquid Glass behavior.

Stable confirmation images, nine per OS:
.superpowers/sdd/2026-10-22-native-macos-ui/visual-v2-review/confirmation-7105938/{macos-26,macos-27}/
Includes list, icons, folders, selected light icons, connected light/dark component at 400x600.
All connected PNGs were visually inspected and fit. Long storage text truncates. Selection is visible in both themes.
The user's rejected screenshot is kept ignored at visual-v2-review/user-rejected.png. Never publish that personal screenshot.

## Local preview

native/macos/build/visual-v2/Build/Products/Release/OpenMTP Native.app
Last release product built from 7105938, locally signed and quarantine-free, 5.424 MiB.
Bundle verification: native/macos/build/visual-v2-bundle.json.
Debug-only diagnostic sources at 881e45c compiled with build-for-testing without running tests.
Debug compile log: native/macos/build/visual-v2-debug-build.log.
Do not open or replace the current user preview. The old final-bca90b9 app was left running from the previous turn.
Rebuild the final release after the functional fix, then verify/sign without launching it.

## Finish

- Fix keyboard issue based on diagnostic logs and get the expanded regression green on both OSes.
- Existing collect-visual-v2.py is prepared but still hardcodes source 7105938, run IDs, and expected counts 47/5/1.
  Update it for the truly successful final source/runs. It requires all suites and benchmarks passing and nine captures per OS.
- Preserve exact JSON summaries, metrics, capture PNGs, hashes under docs/evidence/native-macos/2026-10-22/visual-<finalsha>.
- Write VISUAL-POLISH.md with accurate scope, checks, unresolved physical/manual gaps, and links.
- Keep older 78ac249 evidence unchanged. Add a pointer from existing RESULTS.md to the new visual pass.
- Commit docs/evidence only with [skip ci], push fork, verify remote SHA and clean tree.
- Confirm no owned local test/build processes remain. Do not close the user's old app.
- Final concise status, improved layout/materials/icons, light/dark capture links, test result, and new preview link.
  Opening a new build requires quitting the currently running old preview, so leave that action to the user.

## Parked at user request

The user requested save, commit, push, and a handover. Development stopped.
Current diagnostic results and traces, 18 fixture captures, bundle metadata, and the WIP collector are preserved in
docs/evidence/native-macos/2026-10-22/visual-parked-881e45c/.
The personal screenshot, local binaries, raw downloads, and all unrelated files remain local.
No new tests, builds, app launches, or desktop automation ran while parking.
