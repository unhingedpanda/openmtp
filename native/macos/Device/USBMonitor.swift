import Foundation
import IOKit

@MainActor final class USBMonitor {
    private var port: IONotificationPortRef?
    private var attached: io_iterator_t = 0
    private var detached: io_iterator_t = 0
    private let changed: (Bool) -> Void
    init(changed: @escaping (Bool) -> Void) {
        self.changed = changed
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        IONotificationPortSetDispatchQueue(port, .main)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("IOUSBHostDevice"), { raw, iterator in
            guard let raw else { return }
            MainActor.assumeIsolated {
                let monitor = Unmanaged<USBMonitor>.fromOpaque(raw).takeUnretainedValue()
                if USBMonitor.drain(iterator) { monitor.changed(true) }
            }
        }, context, &attached)
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, IOServiceMatching("IOUSBHostDevice"), { raw, iterator in
            guard let raw else { return }
            MainActor.assumeIsolated {
                let monitor = Unmanaged<USBMonitor>.fromOpaque(raw).takeUnretainedValue()
                if USBMonitor.drain(iterator) { monitor.changed(false) }
            }
        }, context, &detached)
        _ = Self.drain(attached)
        _ = Self.drain(detached)
    }
    private static func drain(_ iterator: io_iterator_t) -> Bool {
        var found = false
        while true {
            let object = IOIteratorNext(iterator)
            if object == 0 { return found }
            found = true
            IOObjectRelease(object)
        }
    }
    func stop() {
        if attached != 0 { IOObjectRelease(attached); attached = 0 }
        if detached != 0 { IOObjectRelease(detached); detached = 0 }
        if let port { IONotificationPortDestroy(port); self.port = nil }
    }
}
