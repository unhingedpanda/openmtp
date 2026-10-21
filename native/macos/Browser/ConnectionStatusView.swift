import SwiftUI

struct ConnectionStatusView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Image(systemName: "laptopcomputer").font(.system(size: 48, weight: .ultraLight))
                Image(systemName: "cable.connector.horizontal").font(.system(size: 24, weight: .light))
                    .foregroundStyle(.tertiary)
                Image(systemName: "smartphone").font(.system(size: 52, weight: .ultraLight))
            }
            .foregroundStyle(.secondary).frame(height: 84).accessibilityHidden(true)
            Text(model.connecting ? "Connecting…" : "Connect your device")
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 16).accessibilityIdentifier("connection-title")
            Text(model.connectionMessage ?? "Use a USB cable, then choose File Transfer\non your device.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(4)
                .frame(maxWidth: 280).padding(.top, 10)
                .accessibilityIdentifier("connection-explanation")
            Button {
                model.connectAction?()
            } label: {
                Label(model.connecting ? "Connecting…" : (model.connectionMessage == nil ? "Connect" : "Retry"), systemImage: "arrow.clockwise")
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.glass).controlSize(.large)
            .disabled(model.connecting || model.engineBusy).padding(.top, 22)
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
