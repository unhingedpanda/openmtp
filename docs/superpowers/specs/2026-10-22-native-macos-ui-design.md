# OpenMTP native Mac interface design

Status: proposed written specification, following the user's approval of the direction in chat.

## Outcome

Build a native Mac interface that keeps OpenMTP's familiar two-pane file-transfer workflow.
Use SwiftUI and AppKit with the existing Kalam engine.
The user wants a focused refinement of the product and authentic Apple behavior.

## First-build boundary

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

Intel support, older macOS support, immediate transfer cancellation, Finder mounting, and new protocol implementations are deferred.
Quick Look and additional file-manager features are deferred until the preserved workflow works correctly.
macOS 26 runtime compatibility remains unverified until that release is tested.
The user authorized public-fork remote verification on 2026-10-22 after parking the initial implementation.
Desktop automation on the user's Mac remains disabled.
Remote measurements do not establish performance on the user's Mac.

## Interface

Keep one main window with local files on the left and device files on the right.
Preserve a reversible pane order and an adjustable divider.
Start at 1100 by 740 points, with an 880 by 640 point minimum.
Persist window placement, pane order, divider position, and each pane's view preference.

Each pane has a location header, path navigation, list/grid switch, file content, and a compact item-count footer.
The device header includes the current storage selection.
Use standard system typography, colors, file icons, selection treatment, and focus indicators.
Keep file names, sizes, and dates readable at normal desktop density.

Use native toolbar groups for navigation, new folder, transfer, and view controls.
The active pane owns keyboard actions and contextual actions.
Transfer actions state their destination explicitly.
Disable operations when selection, device state, or current work makes them unavailable.

Use native Liquid Glass appearance for suitable toolbar and navigation controls.
Keep file lists on a quiet system content background.
Use a compact transfer area below the panes, expandable when details are useful.
Respect system dark mode, reduced transparency, increased contrast, and reduced motion.
Use restrained system transitions and immediate press feedback.

Apple's checked-now guidance supports standard components and restrained glass use:

- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

## Preserved behavior

- Browse local and device folders in list and grid views.
- Select files with ordinary click, Command-click, Shift-click, and keyboard navigation.
- Navigate folders with familiar Mac keyboard actions.
- Create folders and rename items inline.
- Copy files and folders in both directions.
- Support drag-and-drop between panes and imports from Finder.
- Support exports to Finder through native file promises.
- Select internal storage or SD storage when the engine reports them.
- Show observed transfer progress, current item, speed, and failures.
- Confirm permanent device deletion.
- Move local deletions to Trash when the filesystem supports it.
- Require an explicit collision decision before replacing existing content.

Preserve file names and full integer file sizes across the bridge.
Never show a completed transfer before the engine reports completion.
Do not advertise automatic resume or atomic device writes.

## Connection and failure states

Provide distinct states for disconnected, connecting, ready, busy, access denied, unsupported device, and transfer failure.
The disconnected state explains cable connection and the phone's file-transfer mode.
Show actionable errors with a retry action where appropriate.
Retain failed transfer details until the user dismisses or retries them.

USB attach and detach notifications schedule work through the session controller.
Do not initialize or dispose a session concurrently with a transfer.
Invalidate device identifiers and selections after disconnects or session changes.
When the engine reports multiple devices, explain its single-device limitation.

## Architecture

Use an XcodeGen project with an application target and focused test targets.
Use SwiftUI for the window, toolbar composition, settings, sheets, and transfer presentation.
Use AppKit-backed file lists and collections for selection, keyboard behavior, drag-and-drop, and large directory handling.

Separate these responsibilities:

| Component | Responsibility |
| --- | --- |
| Native application shell | Window lifecycle, menus, settings, and system appearance |
| Browser pane | Presentation and interaction for one location |
| Browser model | Navigation, selection, sorting, and typed entries |
| Local file service | Local enumeration, metadata, rename, folder creation, and Trash |
| Device session | Serialized Kalam operations and connection state |
| Transfer coordinator | Queue, collision decisions, progress, completion, and stopping |
| Kalam bridge | C calls, JSON conversion, callback lifetime, and native library loading |

Keep blocking USB operations off the main thread.
Deliver UI state changes on the main actor.
Allow one Kalam operation at a time.
Do not rely on the existing Go lock helper for operation serialization.

Checked now: the C interface exposes initialization, browsing, file operations, upload, download, and disposal.
Its header contains no cancellation entry point.
Source: `build/mac/bin/arm64/kalam.h:82`.

Checked now: callbacks receive allocated C strings from `send_to_js`.
Define callback ownership and prove its implementation before connecting the UI.
Source: `ffi/kalam/native/send_to_js/main.go:27`.

Checked now: the arm64 library depends on a companion libusb library through `@loader_path`.
Preserve the correct library pair and its relative location in the native bundle.
Source: `build/mac/bin/arm64/kalam-seg5.dylib`, inspected with `otool -L`.
Follow the upstream version-selection rule in `app/helpers/binaries.js`.

## Stopping and data safety

The first version stops queued work after the current item finishes.
Label the control `Stop after current item`.
Keep that wording accurate when the current item is a folder.
Do not implement apparent cancellation by calling Dispose during a transfer.
Immediate cancellation requires separate backend design and is outside this port.

On failure, report the affected item and any possible partial copy.
Never delete or replace unrelated destination content during cleanup.
Use disposable fixture folders for device acceptance testing.
Require an explicit decision before closing the app during active work.

## Performance acceptance

These are proposed acceptance targets, not measured results or promises.

| Metric | First-build target and workload |
| --- | --- |
| Uncompressed arm64 bundle | At most 50 MiB, including bundled engine dependencies |
| Warm first-window time | Median at most 0.75 seconds over ten launches on this Mac |
| Memory | At most 150 MiB summed RSS after 30 seconds, with a 1000-entry local fixture and no device |
| Idle CPU | At most 1% of one core over 30 seconds under that same fixture |
| Browsing | Selection and keyboard responses within 100 milliseconds at the 95th percentile, across 100 actions in a 10000-entry local fixture |
| Transfer integrity | Exact byte counts and round-trip SHA-256 matches for disposable device fixtures |
| Transfer throughput | Report against OpenMTP using the same phone, cable, files, and timing method |

Report missed targets without relaxing them silently.
Keep physical footprint and summed RSS measurements clearly distinguished.
Do not infer device throughput from UI benchmarks.

## Verification and evidence

Test selection, sort order, typed bridge decoding, queue transitions, collision decisions, and stale device-state rejection.
Exercise malformed callback data, large sizes, non-ASCII names, and repeated progress callbacks.
Test that blocking engine operations cannot run on the main thread.
Test that stopping a queue cannot start its remaining items.

Build and launch the actual app bundle.
Verify library loading and the real disconnected state before claiming engine integration.
Inspect light and dark appearance, narrow windows, keyboard focus, and accessibility settings.
Keep preview fixtures explicitly separate from real device state.

When a test phone is available, validate upload, download, folders, collisions, rename, deletion, disconnects, and storage-full errors.
Use one large file and a batch of small files for throughput comparisons.
Record phone, storage, cable, host, build revision, repetitions, and checksum results.
Mark all unavailable hardware checks as unverified.

## Delivery sequence

1. Prove the C bridge, native library loading, and serialized device session.
2. Build the native two-pane browser with local files and real connection states.
3. Connect file operations, transfers, collision handling, and native drag-and-drop.
4. Validate appearance, accessibility, performance, and available device behavior.

The implementation plan will map this sequence to files, interfaces, tests, and exact verification commands.
