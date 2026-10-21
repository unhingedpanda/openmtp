# OpenMTP Native Mac Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a separate native OpenMTP preview that preserves the existing file-transfer workflow.

**Architecture:** SwiftUI owns application composition and system controls. AppKit owns file-list and grid interactions. A serialized Swift service calls the existing Kalam C interface.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, XCUITest, XcodeGen, existing arm64 Kalam and libusb libraries.

**Spec:** `docs/superpowers/specs/2026-10-22-native-macos-ui-design.md`.

## Global Constraints

- Deployment target: macOS 26.0 or later.
- Initial architecture: arm64.
- Initial runtime validation: this Apple Silicon Mac running macOS 27.0.1.
- Preview bundle: `OpenMTP Native.app`.
- Preview bundle identifier: `dev.yash.openmtp.native`.
- Native source boundary: `native/macos/` inside this checkout.
- Keep the installed `/Applications/OpenMTP.app` untouched.
- Keep existing Electron sources and Go sources untouched during the port.
- Publish only to the user's public fork for authorized remote verification.
- Do not install over OpenMTP or claim upstream endorsement.
- Label the control `Stop after current item`.
- Immediate cancellation requires separate backend design and is outside this port.
- Keep blocking USB operations off the main thread.
- Deliver UI state changes on the main actor.
- Allow one Kalam operation at a time.
- Keep preview fixtures explicitly separate from real device state.
- Mark all unavailable hardware checks as unverified.

The specification's performance targets remain acceptance targets throughout execution.
The user authorized public-fork remote verification on 2026-10-22 after parking the initial implementation.
Desktop automation on the user's Mac remains disabled.
Remote measurements do not establish performance on the user's Mac.
Do not silently relax them when measurements miss them.
Use system controls and the approved Apple appearance without adding product features.
Preserve the existing source licenses and bundled dependency notices.

## Review Focus

1. A disconnected phone must not leave actionable entries from its previous session.
2. Callbacks must not outlive their operation or release a string twice.
3. Failed transfers and name collisions must not damage unrelated destination content.
4. Focus changes must not send keyboard or destructive actions to the wrong pane.
5. File promises must remain valid until export completes, including when the source window closes.

Each owning task below includes a regression check for its review focus.

## File and verification conventions

Create the XcodeGen configuration at `native/macos/project.yml`.
Generate `native/macos/OpenMTPNative.xcodeproj` with an application, unit-test, and UI-test target.
Keep generated build output under `native/macos/build/` and exclude it from Git.
Build the app as `OpenMTP Native.app` with its distinct preview identifier.
Use a framework-free unit-test target that compiles the relevant production files directly.

From the repository root, generate the project with:

```sh
xcodegen generate --spec native/macos/project.yml
```

Use this command for the complete unit suite:

```sh
xcodebuild test -project native/macos/OpenMTPNative.xcodeproj -scheme OpenMTPNative -destination 'platform=macOS,arch=arm64' -derivedDataPath native/macos/build -only-testing:OpenMTPNativeTests CODE_SIGNING_ALLOWED=NO
```

Call this command **UNIT** below.
Add `-only-testing:OpenMTPNativeTests/<TestClass>` to the corresponding focused test invocation instead of the broad selector.
Keep full command output in local evidence files and inspect failures directly.
Write tests before any minimal interface stubs needed for compilation.
Observe the intended behavioral failure before implementing the corresponding behavior.

## Task 1: Prove the bridge and device session

**Files:**
- Create: `native/macos/project.yml`, `native/macos/.gitignore`.
- Create: `native/macos/Core/FileEntry.swift`, `native/macos/Device/DeviceModels.swift`.
- Create: `native/macos/Bridge/KalamBridge.h`, `native/macos/Bridge/KalamBridge.c`.
- Create: `native/macos/Device/KalamTransport.swift`, `native/macos/Device/DeviceSession.swift`.
- Create: `native/macos/Tests/DeviceSessionTests.swift`, `native/macos/Tests/BridgeDecodingTests.swift`.
- Create: `native/macos/Tests/Support/ScriptedTransport.swift`, `native/macos/Tests/Support/FixtureKalam.c`.

**Interfaces:**
- Produce `EntryLocation.local(URL)` and `EntryLocation.device(storageID: UInt32, path: String)`.
- Produce `FileEntry(location:name:isDirectory:byteCount:modifiedAt:)`, using `Int64` sizes and optional dates.
- Produce `DeviceStorage(id: UInt32, name: String)` and typed connection, error, and progress models.
- Produce typed `DeviceRequest` cases for the 11 existing exported operations.
- Produce `DeviceReply.device`, `.storages`, `.entries`, `.existence`, and `.confirmed` results.
- Produce `KalamTransport.invoke(_ request: DeviceRequest, onProgress: @Sendable (TransferProgress) -> Void) throws -> DeviceReply`.
- Produce `DeviceSession.perform(_ request: DeviceRequest, onProgress: @Sendable (TransferProgress) -> Void) async throws -> DeviceReply`.
- Produce `DeviceSession.invalidate()`, which rejects results from earlier session generations.

- [ ] Write behavior tests before their production implementations.

```swift
func testRejectsOldSessionEntriesAfterDisconnect()
func testNeverRunsBlockingTransportOnMainThread()
func testSerializesOverlappingRequests()
func testPreservesUnicodeNamesAndInt64Sizes()
func testRejectsMalformedOrErrorCallbackResults()
func testCopiesAndReleasesCallbackStringsExactlyOnce()
func testFinishesOnlyAfterTerminalCallbackAndForeignReturn()

// Assertions on decoded data and observed execution:
XCTAssertEqual(decoded.byteCount, 9_007_199_254_740_993)
XCTAssertEqual(decoded.name, "旅行📷.jpg")
XCTAssertEqual(maximumConcurrentInvocations, 1)
XCTAssertFalse(invokedOnMainThread)
XCTAssertEqual(callbackAllocations, callbackReleases)
XCTAssertTrue(visibleEntriesAfterDisconnect.isEmpty)
```

Assertions: stale results cannot become visible, maximum concurrent engine calls equals one, and main-thread invocation count equals zero.
Decode a `9007199254740993` byte size exactly.
Preserve the name `旅行📷.jpg` exactly.
Use an instrumented C fixture to verify callback ownership and callback completion order.
Derive fixture field names from the checked-in Go result structs and existing JavaScript adapter.

- [ ] Run the focused classes and confirm failures identify the missing behavior.
- [ ] Implement the models, C adapter, decoder, and dedicated serial execution queue.

Copy each callback string before freeing its C allocation.
Retain operation context until the foreign call returns and its terminal callback has arrived.
Resolve required symbols before starting device work.
Load the paired arm64 Kalam and libusb libraries from the preview bundle.
Keep the upstream files unchanged and preserve their relative loader paths.
Report missing libraries and missing symbols as typed errors.

- [ ] Run UNIT and inspect every failure.
Expected: all unit tests pass, including the C ownership fixture.
- [ ] Commit only Task 1 files with `feat: bridge native device sessions to Kalam`.

## Task 2: Build the native shell and local browser

**Files:**
- Create: `native/macos/App/OpenMTPNativeApp.swift`, `native/macos/App/AppModel.swift`.
- Create: `native/macos/App/AppCommands.swift`, `native/macos/App/SettingsView.swift`.
- Create: `native/macos/Browser/PaneModel.swift`, `native/macos/Browser/LocalFileService.swift`.
- Create: `native/macos/Browser/BrowserPane.swift`, `native/macos/Browser/FileTableView.swift`, `native/macos/Browser/FileGridView.swift`.
- Create: `native/macos/Tests/LocalFileServiceTests.swift`, `native/macos/Tests/PaneModelTests.swift`.
- Create: `native/macos/UITests/BrowserInteractionTests.swift`.

**Interfaces:**
- Consume Task 1 entry and session models.
- Produce `LocalFileService.entries(at:) async throws -> [FileEntry]`.
- Produce `PaneModel.navigate(to:)`, `setSelection(_:)`, and persisted `viewMode` and sort state.
- Produce `AppModel.activePane`, `localPane`, `devicePane`, and `session`.
- Produce native browser callbacks for activation, selection, rename, context actions, and drops.

- [ ] Write unit and UI tests for the local browser before implementing its behavior.

```swift
func testFolderNavigationClearsPreviousSelection()
func testRangeSelectionUsesVisibleSortOrder()
func testPreferencesRestorePaneOrderAndViewMode()
func testPermissionFailureRetainsLastValidLocation()
func testKeyboardActionUsesTheFocusedPane()

// Assertions on the visible pane state:
XCTAssertEqual(selectedLocations, Set(sortedEntries[2...7].map(\.location)))
XCTAssertEqual(locationAfterDeniedNavigation, lastValidLocation)
XCTAssertTrue(selectionAfterSuccessfulNavigation.isEmpty)
XCTAssertEqual(actionDestination, focusedPaneLocation)
```

Assertions: navigation shows the requested directory, range selection follows sorted rows, and actions cannot target the inactive pane.
Use temporary local directories and a separate preview defaults suite.
Create UI fixtures through explicit test launch arguments, without changing live device status.

- [ ] Run the focused tests and confirm the expected failures.
- [ ] Implement the main window, split layout, native file controls, location headers, footers, and settings.

Use the specification's 1100 by 740 point initial size and 880 by 640 point minimum.
Use native system typography, file icons, focus rings, and toolbar grouping.
Apply system Liquid Glass to suitable controls while keeping file content on a quiet background.
Preserve adjustable pane order, divider position, list/grid mode, and window placement.
Keep the device pane genuinely disconnected until its session succeeds.

- [ ] Run UNIT and `BrowserInteractionTests` through XCUITest.
Expected: all unit tests pass, and real keyboard and selection interactions pass.
- [ ] Commit only Task 2 files with `feat: add native two-pane file browser`.

## Task 3: Connect device browsing and file operations

**Files:**
- Create: `native/macos/Device/USBMonitor.swift`, `native/macos/Device/DeviceFileService.swift`.
- Create: `native/macos/Browser/FileActionController.swift`, `native/macos/Browser/ConnectionStatusView.swift`.
- Create: `native/macos/Tests/DeviceBrowsingTests.swift`, `native/macos/Tests/FileActionTests.swift`.
- Modify: `AppModel.swift`, `PaneModel.swift`, `AppCommands.swift`, and `BrowserPane.swift` from Tasks 1–2.

**Interfaces:**
- Consume `DeviceSession.perform(_:onProgress:)` and the active-pane contract.
- Produce `DeviceFileService.entries(storage:path:)`, `makeDirectory`, `rename`, `delete`, and `exists` operations.
- Produce equivalent local mutation methods on `LocalFileService`.
- Produce `FileActionController` actions that resolve the active pane at invocation time.
- Produce an IOKit USB notification source that schedules session work without concurrent engine calls.

- [ ] Write tests for device navigation and file mutations before their implementations.

```swift
func testDisconnectInvalidatesSelectionAndPendingNavigation()
func testStorageChangeRejectsOldDirectoryResults()
func testAttachDuringTransferDefersSessionReset()
func testDeviceDeleteRequiresConfirmation()
func testLocalDeleteUsesTrash()
func testRenameRejectsPathSeparatorsAndNameCollisions()

// Assertions on state and disposable filesystem fixtures:
XCTAssertTrue(visibleEntriesAfterDisconnect.isEmpty)
XCTAssertTrue(selectionAfterStorageChange.isEmpty)
XCTAssertTrue(originalExistsBeforeConfirmation)
XCTAssertTrue(trashedFixtureExists)
XCTAssertEqual(existingCollisionBytes, originalCollisionBytes)
```

Assertions: old device entries cannot be acted on, device deletion needs explicit confirmation, and local deletion uses Trash where supported.
Display the engine's multiple-device limitation rather than inventing a device selector.

- [ ] Run the focused tests and confirm the expected failures.
- [ ] Implement device connection, storage selection, browsing, mutation commands, and actionable errors.
- [ ] Run UNIT and the browser UI tests.
Expected: all automated checks pass, and the real bundled engine reports an accurate disconnected state without a phone.
- [ ] Commit only Task 3 files with `feat: connect native browsing and file actions`.

## Task 4: Implement transfers and destination protection

**Files:**
- Create: `native/macos/Transfers/TransferModels.swift`, `native/macos/Transfers/TransferCoordinator.swift`.
- Create: `native/macos/Transfers/CollisionResolver.swift`, `native/macos/Transfers/TransferTray.swift`.
- Create: `native/macos/Tests/TransferCoordinatorTests.swift`, `native/macos/Tests/CollisionTests.swift`.
- Modify: `AppModel.swift`, `AppCommands.swift`, and `BrowserPane.swift`.

**Interfaces:**
- Consume the local file service, device file service, and serialized session.
- Produce `TransferCoordinator.enqueue(_:)`, `stopAfterCurrentItem()`, and observable queue and progress state.
- Produce `TransferItem(source:destination:)`, with a complete folder counting as one queue item.
- Produce collision decisions `.replace`, `.skip`, and `.stop`.

- [ ] Write transfer behavior tests before implementation.

```swift
func testStopAfterCurrentItemDoesNotStartRemainingItems()
func testTerminalErrorNeverProducesCompletedState()
func testExistingDestinationRequiresCollisionDecision()
func testFailedCopyPreservesUnrelatedDestinationContent()
func testProgressFromPreviousItemCannotUpdateNextItem()
func testCloseDuringTransferRequiresExplicitDecision()

// Assertions on queue outcomes and destination content:
XCTAssertEqual(completedItemIDsAfterStopping, [firstItem.id])
XCTAssertFalse(failedItemShownAsComplete)
XCTAssertEqual(unrelatedDestinationBytes, originalUnrelatedBytes)
XCTAssertEqual(progressAfterStaleCallback, currentItemProgress)
XCTAssertFalse(quitWithoutUserDecision)
```

Assertions: queued work stops accurately, reported completion follows engine completion, and cleanup cannot touch unrelated files.
Use temporary directories and the scripted transport to exercise failures deterministically.

- [ ] Run the focused tests and confirm the expected failures.
- [ ] Implement sequential queue execution, collision sheets, transfer feedback, retained failures, and active-transfer close handling.

Show the exact label `Stop after current item`.
Do not call Dispose to simulate cancellation.
Keep progress and speed derived from observed engine data.
Report partial copies without claiming atomic writes or automatic resume.

- [ ] Run UNIT and the applicable UI tests.
Expected: all queue, collision, progress, and close-handling checks pass.
- [ ] Commit only Task 4 files with `feat: add native transfers and destination protection`.

## Task 5: Complete native drag-and-drop

**Files:**
- Create: `native/macos/Transfers/FilePromiseDelegate.swift`, `native/macos/Transfers/DropCoordinator.swift`.
- Create: `native/macos/Tests/FilePromiseTests.swift`, `native/macos/UITests/TransferInteractionTests.swift`.
- Modify: `FileTableView.swift`, `FileGridView.swift`, and `TransferCoordinator.swift`.

**Interfaces:**
- Consume `TransferCoordinator.enqueue(_:)` and collision decisions.
- Produce `DropCoordinator.accept(_:destination:)` using local file URLs or validated internal device references.
- Produce `FilePromiseDelegate` through `NSFilePromiseProviderDelegate`, retaining its operation until completion.

- [ ] Write drag-and-drop and file-promise tests before implementation.

```swift
func testPromiseCompletesOnlyAfterDestinationFileExists()
func testPromiseSurvivesSourceWindowClosure()
func testPromiseReportsDisconnectFailure()
func testDropUsesTheTargetPaneAndItsCurrentLocation()
func testStaleDeviceReferenceCannotStartExport()

// Assertions on the promised output and reported outcome:
XCTAssertTrue(FileManager.default.fileExists(atPath: promisedURL.path))
XCTAssertEqual(try Data(contentsOf: promisedURL), sourceBytes)
XCTAssertNotNil(errorReportedForDisconnectedExport)
XCTAssertEqual(acceptedDropDestination, targetPaneLocation)
```

Assertions: exported files exist before success, failure reaches the requester, and stale device references never start a transfer.
Exercise Finder import and export manually with disposable fixtures after automated checks.

- [ ] Run the focused tests and confirm the expected failures.
- [ ] Implement native pasteboard types, inter-pane drops, Finder imports, and promised Finder exports.
- [ ] Run UNIT and all native UI tests.
Expected: automated checks pass, with physical-device drag tests reported separately when unavailable.
- [ ] Commit only Task 5 files with `feat: support native file drag and drop`.

## Task 6: Measure and review the complete preview

**Files:**
- Create: `native/macos/Scripts/benchmark.py`, `native/macos/Scripts/make-fixtures.py`, `native/macos/Scripts/verify.sh`.
- Create: `native/macos/README.md`, `native/macos/THIRD_PARTY_NOTICES.md`.
- Create: `docs/evidence/native-macos/2026-10-22/RESULTS.md`.
- Modify: the native files identified by actual verification failures.

**Interfaces:**
- Consume the completed app bundle and preceding test suites.
- Produce JSON measurements, appearance captures, and a requirement-by-requirement acceptance report.
- Produce a launch command that opens the preview from its build directory.

- [ ] Add acceptance checks for bundle contents, missing dependencies, and accidental Electron inclusion before packaging changes.
- [ ] Run those checks and confirm the expected failures.
- [ ] Finish resource copying, relative library loading, local signing, and source attribution.
- [ ] Run UNIT and the full XCUITest target through the app scheme.
Expected: every automated test passes, and failures receive regression tests before fixes.
- [ ] Build and launch the actual preview bundle from its build directory.
Expected: the app loads Kalam and reports real connection state without replacing the installed app.
- [ ] Inspect light and dark modes, narrow windows, focus, reduced transparency, increased contrast, and reduced motion.
- [ ] Measure the specification's bundle, launch, memory, CPU, and 10000-entry interaction targets on this Mac.

```python
assert "Electron Framework.framework" not in shipped_paths
assert bundle_mib <= 50
assert median_warm_window_seconds <= 0.75
assert no_device_rss_mib <= 150
assert idle_cpu_one_core_percent <= 1
assert browser_action_p95_ms <= 100
```

- [ ] Record every missed target without changing the thresholds.
- [ ] Run disposable device checks when a test phone is available.

Verify uploads, downloads, folders, collisions, rename, deletion, disconnects, and storage-full errors.
Compare throughput using the same phone, cable, file corpus, and timing method as OpenMTP.
Record round-trip checksums and mark missing device or macOS 26 validation as unverified.

- [ ] Request one independent whole-branch review with the spec, plan, diff, test output, captures, and measurements.
- [ ] Fix material findings with failing regression checks and rerun the affected full gate.
- [ ] Commit the verified native changes and acceptance report without publishing or pushing.

## Self-review and execution handoff

The six tasks cover the specification's four delivery stages.
Tasks 1–5 establish behavior before final packaging and measurement.
All five review-focus cases have named regression checks in their owning task.
The plan introduces no Rust port, engine changes, Quick Look, Finder mounting, or public release.

Recommended execution: inline implementation with one independent whole-branch review.
The tasks share session, pane, and transfer contracts, so sequential implementation avoids repeated context setup.
Per-task implementation and review agents remain an alternative if the user prefers that workflow.

Implementation begins only after the user reviews this written plan and selects the execution method.
