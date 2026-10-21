---
name: OpenMTP Native
description: A native Mac workspace for USB file transfer.
typography:
  pane-title:
    fontFamily: System
    fontSize: 16pt
    fontWeight: 600
  file-name:
    fontFamily: System
    fontSize: 13pt
    fontWeight: 400
  supporting:
    fontFamily: System
    fontSize: 12pt
    fontWeight: 400
  status:
    fontFamily: System
    fontSize: 11pt
    fontWeight: 400
  connection-title:
    fontFamily: System
    fontSize: 22pt
    fontWeight: 600
rounded:
  canvas: 14pt
spacing:
  gutter: 12pt
components:
  file-grid-item:
    width: 112pt
    height: 116pt
  file-grid-icon:
    width: 64pt
    height: 64pt
  folder-navigation:
    height: 40pt
  selection-status:
    height: 30pt
  device-storage:
    width: 140pt
---
# OpenMTP Native design

## Overview

Keep the recognizable Mac-to-device workflow. Make browsing feel like a focused Mac utility.
The user asked for Apple-native controls and Liquid Glass, then rejected the sparse initial preview.
This pass improves layout, materials, and file presentation together without changing the transfer engine.
The native SwiftUI and AppKit sources remain authoritative for platform styling.

## Colors

Colors use semantic system roles rather than fixed swatches.
`NSColor.windowBackgroundColor` carries window chrome. `NSColor.textBackgroundColor` carries file content.
Primary and secondary foreground styles follow appearance. The current system accent identifies the active pane and selection.
`NSWorkspace` supplies actual local file icons and generic device file types.
Do not substitute the design database's web palettes or web fonts for these native roles.

## Typography

Use the system font and the roles above. File names support two lines in icon view.
Native controls retain their platform typography and dimensions. Connection explanations use the body scale with extra line spacing.

## Layout

Two resizable browsers share equal initial space. Each has a source header, compact folder navigation,
file canvas, and status footer. The disconnected device keeps this structure and explains the next action.
The native split divider remains visible and draggable. Each browser has a minimum width of 400 points.
The window toolbar provides Mac locations, folder creation, transfer, and secondary actions.
The transfer action includes its name. Each pane owns its native path control and refresh action.
Storage names truncate inside their allocated width, and their full value remains available through native semantics and help.

## Elevation & Depth

Native toolbar glass and the native glass connection button sit above opaque file content.
Bar material separates paths and status from file content. Avoid decorative blur, gradients, and continuous motion.
This follows [Apple's Liquid Glass guidance](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).
Static captures verify composition. They cannot establish live material behavior.

## Shapes

File canvases share the corner token above. Native controls retain system shapes.
The active canvas uses a subtle accent outline. File icons scale proportionally to fill their frames.

## Components

Preserve native list and grid selection, keyboard navigation, rename, drag and drop, view preferences,
storage selection, pane swapping, and transfer safety. Native folder paths support double-clicking an ancestor.
Device paths identify the device and cannot export a fake local file URL.
The connection state retains the existing explanation and recovery action.

## Do's and Don'ts

- Keep native controls, system icons, and semantic color roles.
- Keep file content legible beneath the navigation layer.
- Preserve visible selection and the native split divider.
- Verify light and dark list, icon, selection, and connected-storage states.
- Keep local desktop automation off until the user authorizes it.
- Use hosted UI tests and captures for this pass.
- Treat visual acceptance, physical phone testing, and manual accessibility as separate evidence.
