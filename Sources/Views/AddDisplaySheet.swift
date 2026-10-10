import SwiftUI
import AppKit

public struct AddDisplaySheet: View {
    @ObservedObject var sidecarService = SidecarService.shared
    @ObservedObject var manager = DisplayManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add & Connect Displays")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Connect iPad Pro over high-speed USB-C, wireless Sidecar, or external HDMI.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("iPad Pro (USB Cable)").tag(0)
                Text("Wireless Sidecar / AirPlay").tag(1)
                Text("Zebronics HDMI Monitor").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content per tab
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedTab == 0 {
                        // iPad via USB Cable
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("High-Speed USB-C Cable (Recommended)", systemImage: "cable.connector")
                                    .font(.headline)
                                Spacer()
                                Text("Low Latency / 120Hz")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .cornerRadius(6)
                            }

                            Text("Connecting your iPad Pro to your MacBook Air via a direct USB-C cable bypasses wireless interference, maintains constant battery charging, and provides maximum refresh rate performance.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Divider()

                            // Live detected Sidecar devices
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Discovered iPads & Sidecar Targets:")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Button {
                                        sidecarService.scanDevices()
                                    } label: {
                                        Label("Scan", systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(sidecarService.isScanning)
                                }

                                if sidecarService.availableDevices.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "ipad.and.arrow.forward")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.tertiary)
                                        Text("No iPads currently detected via SidecarCore.")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("Follow the 3-step checklist below to connect.")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(8)
                                } else {
                                    ForEach(sidecarService.availableDevices) { device in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(device.name)
                                                    .font(.headline)
                                                Text(device.model)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if device.isConnected {
                                                Button("Disconnect") {
                                                    sidecarService.disconnect(device: device) { _ in
                                                        manager.refreshDisplays()
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                            } else {
                                                Button("Connect as Display") {
                                                    sidecarService.connect(device: device) { _ in
                                                        manager.refreshDisplays()
                                                    }
                                                }
                                                .buttonStyle(.borderedProminent)
                                            }
                                        }
                                        .padding(12)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(8)
                                    }
                                }
                            }

                            Divider()

                            // USB Connection Checklist
                            VStack(alignment: .leading, spacing: 8) {
                                Text("USB Connection Checklist for iPad Pro:")
                                    .font(.subheadline)
                                    .fontWeight(.bold)

                                ChecklistRow(number: "1", title: "Plug USB-C Cable", detail: "Connect a USB-C to USB-C cable between your MacBook Air and iPad Pro.")
                                ChecklistRow(number: "2", title: "Unlock & Trust", detail: "Unlock your iPad Pro screen. If asked 'Trust This Computer?', tap Trust.")
                                ChecklistRow(number: "3", title: "Apple Account & Handoff", detail: "Ensure both devices are signed into the same Apple Account with Wi-Fi and Bluetooth ON.")
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(10)

                            HStack(spacing: 12) {
                                Button {
                                    sidecarService.openSystemAddDisplaySettings()
                                } label: {
                                    Label("Open macOS Displays (+)", systemImage: "plus.rectangle.on.rectangle")
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    sidecarService.openScreenMirroring()
                                } label: {
                                    Label("Control Center Mirroring", systemImage: "airplayvideo")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } else if selectedTab == 1 {
                        // Wireless Sidecar / AirPlay
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Wireless Sidecar & AirPlay 2", systemImage: "wifi")
                                    .font(.headline)
                                Spacer()
                                Text("AWDL Peer-to-Peer")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .cornerRadius(6)
                            }

                            Text("Stream macOS desktop wirelessly to your iPad Pro using Apple Wireless Direct Link (AWDL) with hardware H.264/HEVC compression.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Wireless Requirements:")
                                    .font(.subheadline)
                                    .fontWeight(.bold)

                                ChecklistRow(number: "1", title: "Same Wi-Fi Network", detail: "Connect both MacBook Air and iPad Pro to the same Wi-Fi network.")
                                ChecklistRow(number: "2", title: "Bluetooth Enabled", detail: "Turn ON Bluetooth on both devices for peer-to-peer discovery.")
                                ChecklistRow(number: "3", title: "Within 30 Feet", detail: "Keep devices close for minimum latency.")
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(10)

                            HStack(spacing: 12) {
                                Button {
                                    sidecarService.openSystemAddDisplaySettings()
                                } label: {
                                    Label("Add Wireless Display in Settings", systemImage: "plus.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    sidecarService.openScreenMirroring()
                                } label: {
                                    Label("Open Screen Mirroring", systemImage: "airplayvideo")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } else {
                        // Zebronics HDMI External Monitor
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Zebronics HDMI External Monitor", systemImage: "display.2")
                                    .font(.headline)
                                Spacer()
                                Text("100Hz Full HD")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundStyle(.orange)
                                    .cornerRadius(6)
                            }

                            if let zeb = manager.displays.first(where: { $0.recognizedType == .zebronicsExternal || $0.currentRefreshRate >= 99.0 }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Monitor Detected & Active:")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.green)

                                    Text("Name: \(zeb.displayName)")
                                    Text("Live Resolution: \(zeb.pointWidth) x \(zeb.pointHeight)")
                                    Text("Live Refresh Rate: \(String(format: "%.0f", zeb.currentRefreshRate)) Hz")
                                    Text("Connection Bus: \(zeb.connectionBus)")
                                    Text("Color Profile: \(zeb.currentColorProfileName)")
                                }
                                .padding()
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(10)
                            } else {
                                Text("External HDMI monitor is not currently detected. Plug in your USB-C to HDMI adapter or check monitor power.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Hardware Connection Guide:")
                                    .font(.subheadline)
                                    .fontWeight(.bold)

                                ChecklistRow(number: "1", title: "Direct USB-C to HDMI", detail: "Use a certified USB-C to HDMI 2.0/2.1 cable or adapter for 100Hz output.")
                                ChecklistRow(number: "2", title: "Monitor Input", detail: "Ensure the Zebronics monitor is set to HDMI 1 or HDMI 2 input.")
                                ChecklistRow(number: "3", title: "Clamshell vs Dual Mode", detail: "MacBook Air M1/M2 supports 1 external display + internal Retina screen.")
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(10)

                            Button {
                                manager.refreshDisplays()
                            } label: {
                                Label("Refresh & Detect Monitor", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                if let status = sidecarService.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if let error = sidecarService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 580, height: 560)
        .onAppear {
            sidecarService.scanDevices()
        }
    }
}

struct ChecklistRow: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
