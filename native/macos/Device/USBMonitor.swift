import Foundation
import IOKit

@MainActor final class USBMonitor {
    private var port: IONotificationPortRef?
    private var attached: io_iterator_t = 0
    private var detached: io_iterator_t = 0
    private var devices: [UInt64: USBDeviceIdentity] = [:]
    private let changed: (Bool, USBDeviceIdentity?, UInt64) -> Void
    init(changed: @escaping (Bool, USBDeviceIdentity?, UInt64) -> Void) {
        self.changed = changed
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        IONotificationPortSetDispatchQueue(port, .main)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("IOUSBHostDevice"), { raw, iterator in
            guard let raw else { return }
            MainActor.assumeIsolated {
                let monitor = Unmanaged<USBMonitor>.fromOpaque(raw).takeUnretainedValue()
                monitor.consume(iterator, attached: true)
            }
        }, context, &attached)
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, IOServiceMatching("IOUSBHostDevice"), { raw, iterator in
            guard let raw else { return }
            MainActor.assumeIsolated {
                let monitor = Unmanaged<USBMonitor>.fromOpaque(raw).takeUnretainedValue()
                monitor.consume(iterator, attached: false)
            }
        }, context, &detached)
        consume(attached, attached: true, notify: false)
        consume(detached, attached: false, notify: false)
    }
    func registryID(matching identity: USBDeviceIdentity) -> UInt64? {
        let candidates = devices.filter { $0.value.vendor == identity.vendor && $0.value.product == identity.product }
        let exact = candidates.filter { $0.value.serial == identity.serial }
        if exact.count == 1 { return exact.first?.key }
        return candidates.count == 1 ? candidates.first?.key : nil
    }
    private func consume(_ iterator: io_iterator_t, attached: Bool, notify: Bool = true) {
        while true {
            let object = IOIteratorNext(iterator)
            if object == 0 { return }
            defer { IOObjectRelease(object) }
            var registryID: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(object, &registryID) == KERN_SUCCESS else { continue }
            let identity = Self.identity(object) ?? devices[registryID]
            if attached { devices[registryID] = identity }
            else { devices.removeValue(forKey: registryID) }
            if notify { changed(attached, identity, registryID) }
        }
    }
    private static func identity(_ object: io_service_t) -> USBDeviceIdentity? {
        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(object, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        guard let vendor = property("idVendor") as? NSNumber, let product = property("idProduct") as? NSNumber else { return nil }
        let serial = (property("USB Serial Number") as? String).flatMap { $0.isEmpty ? nil : $0 }
        return USBDeviceIdentity(vendor: vendor.uint16Value, product: product.uint16Value, serial: serial)
    }
    func stop() {
        if attached != 0 { IOObjectRelease(attached); attached = 0 }
        if detached != 0 { IOObjectRelease(detached); detached = 0 }
        if let port { IONotificationPortDestroy(port); self.port = nil }
    }
}
