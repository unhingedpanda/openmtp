import SwiftUI

struct ConnectionStatusView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing: 13) {
            Image(systemName: "cable.connector").font(.system(size: 44, weight: .light))
                .foregroundStyle(.tertiary).padding(.bottom, 4)
            Text(model.connecting ? "Connecting…" : "Connect your device")
                .font(.title3.weight(.semibold)).accessibilityIdentifier("connection-title")
            Text(model.connectionMessage ?? "Use a USB cable, then choose File Transfer\non your device.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: 340).accessibilityIdentifier("connection-explanation")
            Button(model.connecting ? "Connecting…" : (model.connectionMessage == nil ? "Connect" : "Retry")) {
                model.connectAction?()
            }.disabled(model.connecting || model.engineBusy).padding(.top, 5)
        }.padding(28)
    }
}
