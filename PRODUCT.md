# OpenMTP native Mac interface

<!-- impeccable:product-schema 1 -->

## Platform

macOS native desktop application.

## Stack

The user approved SwiftUI and AppKit around OpenMTP's existing Kalam engine.
The written specification proposes Apple Silicon and macOS 26 or later for the first local build.
Public compatibility commitments remain undecided.

## Users and purpose

The initial user's intended task is transferring files between this Mac and an Android or other MTP device over USB.
The user dislikes OpenMTP's current interface and wants authentic Apple controls and Liquid Glass.
Success preserves the familiar workflow while improving browsing, transfer feedback, and Mac behavior.

## Capabilities and constraints

Preserve the local and device panes, storage selection, file browsing, uploads, downloads, rename, folder creation, and deletion.
Keep Kalam and its dependencies unchanged during the interface port.
Replace the Electron presentation with native controls.
Keep the installed OpenMTP application available during development.
Use a distinct application identifier and build output for the native preview.
Treat measured performance and real device testing as separate acceptance evidence.

## Design commitments

Use Apple's current native appearance and interaction conventions.
Keep the two-pane workflow recognizable.
Use Liquid Glass for navigation and controls while keeping file content legible.

## Evidence

Checked now: upstream revision is `5da350b69c6d0d4aed67a063498ee89c7448400a`.
Checked now: Kalam exposes a C interface in `build/mac/bin/arm64/kalam.h`.
Checked now: the development Mac has Xcode 27.1, Swift 6.4, and XcodeGen.
Device transfer validation remains outstanding.
