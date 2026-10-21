import SwiftUI

// A minimal control for separating app startup from hosted launch infrastructure.
@main struct LaunchReference: App {
    var body: some Scene {
        WindowGroup("Launch reference") {
            Text("Launch reference").frame(minWidth: 880, minHeight: 640)
        }
        .defaultLaunchBehavior(.presented)
        .defaultSize(width: 880, height: 640)
    }
}
