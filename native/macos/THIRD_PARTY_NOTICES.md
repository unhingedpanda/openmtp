# Third-party notices

This local preview derives from OpenMTP at commit `5da350b69c6d0d4aed67a063498ee89c7448400a`.
OpenMTP is copyright 2010-present Ganesh Rathinavel and uses the MIT license.
The complete license is included in `Licenses/OpenMTP-MIT.txt`.
The app icon comes from the same repository.
This preview does not claim upstream endorsement.

## Device engine

The preview copies the existing arm64 `kalam-seg5.dylib` and `libusb-seg5.dylib` pair from that checkout.
The native frontend does not change their source code.
Local packaging replaces code signatures on the copied libraries.
The original repository copies remain unchanged.

Kalam source: <https://github.com/ganeshrvel/openmtp/tree/5da350b69c6d0d4aed67a063498ee89c7448400a/ffi/kalam/native>.
The library's embedded Go build information reports Go 1.27.0 and the dependencies recorded in `Licenses/engine-modules.json`.
Available dependency license texts and the Go BSD license accompany this file.
The pinned go-mtpx module contains no license file.
Its licensing provenance remains a public-distribution gap.

libusb is a separately loaded dynamic library.
Its license text accompanies this file as `Licenses/libusb-COPYING.txt`.
Upstream source: <https://github.com/libusb/libusb>.
The exact source revision of the prebuilt `libusb-seg5.dylib` has not been established.
Public distribution requires a separate provenance and corresponding-source check.

The app uses Apple's system frameworks and SF Symbols through the installed macOS SDK.
