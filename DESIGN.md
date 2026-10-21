# OpenMTP Native design

Checked 2026-10-22 against the native implementation and the user's rejected screenshot.

## Intent

Keep the recognizable Mac-to-device workflow. Make browsing feel like a focused Mac utility.
The user asked for Apple-native controls and Liquid Glass, then rejected the sparse initial preview.
This pass improves layout, materials, and file presentation together. It keeps the existing engine and transfer behavior.

## Composition

Two resizable browsers share equal initial space. Each has a source header, compact folder navigation,
file canvas, and status footer. The disconnected device keeps this structure and explains the next action.
The window toolbar provides familiar Mac locations, folder creation, transfer, and secondary actions.
The transfer action includes its name. Each pane owns its path and refresh controls.

```
Locations       OpenMTP                         New Folder  Copy to Device  More
This Mac                                Device
Local files                   List Icons       Not connected
╭ Up  native folder path   Refresh ╮   ╭ USB file transfer                    ╮
│                                 │   │                                      │
│  64-point system file icons      │   │         Mac  — cable — device         │
│  or native sortable file rows    │   │         Connect your device          │
│                                 │   │         Explanation                  │
│                                 │   │         Retry                        │
├ Item count or selection status ┤   ├ Item count                           ┤
╰─────────────────────────────────╯   ╰──────────────────────────────────────╯
```

## System

- Typography: the system font. Source titles use 16-point semibold, file names 13-point regular,
  supporting text 12–13 points, and status text 11 points. Connection titles use 22-point semibold.
- Color: semantic AppKit and SwiftUI roles follow the selected system appearance and accent.
  Reference swatches are paper `#FFFFFF`, graphite `#1E1E1E`, chrome `#ECECEC`, ink `#000000`,
  secondary `#666666`, and blue `#007AFF`. These illustrate roles and are not hardcoded theme values.
- Layout: 12-point outer rhythm, 14-point canvas corners, 40-point folder navigation, 30-point footer.
  The file grid uses 112 × 116-point items and 64-point images, with proportional upscaling enabled.
- Materials: native toolbar glass and the native glass connection button sit above opaque file content.
  Bar material separates paths and status from file content. No gradients, decorative blur, or continuous motion.
- Icons: SF Symbols for controls. NSWorkspace supplies actual local file icons and generic device file types.
- Interaction: preserve keyboard navigation, multi-selection, rename, drag and drop, view preferences,
  storage selection, pane swapping, transfer safety, and native focus affordances.

## Verification boundary

No local desktop automation or local app relaunch is authorized for this pass.
Build and bundle checks can run without using the desktop. UI tests and captures run on hosted macOS.
Review light and dark list/icon captures once, then fix material findings in one batch and confirm once.
A passing automation run does not establish that the user likes the result.
