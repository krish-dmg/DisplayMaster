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
                    Text("Add & Connect Any Display")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Universal open-source connection hub for wireless displays, tablets, HDMI/DP monitors, and USB graphics adapters.")
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

            // Universal Category Tabs
            Picker("", selection: $selectedTab) {
                Text("Wireless Displays & Tablets").tag(0)
                Text("Wired Video (HDMI / DP / USB-C)").tag(1)
                Text("USB Adapters & Virtual Displays").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedTab == 0 {
                        // Category 1: Wireless Displays, Tablets, AirPlay & Smart TVs
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Wireless Displays, Tablets & Smart TVs", systemImage: "wifi")
                                    .font(.headline)
                                Spacer()
                                Text("AirPlay 2 & AWDL")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .cornerRadius(6)
                            }

                            Text("Connect any nearby wireless display target: Apple tablets (Sidecar), AirPlay 2 external monitors, Apple TVs, or compatible Smart TVs (LG, Samsung, Sony, Roku).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Divider()

                            // Discovered Devices Section
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Discovered Wireless Display Targets:")
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
                                        Image(systemName: "display.and.arrow.down")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.tertiary)
                                        Text("No wireless display receivers currently detected via auto-discovery.")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("Turn ON Bluetooth & Wi-Fi on both devices or open the macOS Displays Pairing sheet below.")
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
                                                Text("Model: \(device.model)")
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

                            // Wireless Connection Checklist
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Universal Wireless Display Checklist:")
                                    .font(.subheadline)
                                    .fontWeight(.bold)

                                ChecklistRow(number: "1", title: "Wi-Fi & Bluetooth", detail: "Ensure both devices have Wi-Fi and Bluetooth turned ON.")
                                ChecklistRow(number: "2", title: "Screen Mirroring / AirPlay", detail: "Open Control Center or System Displays to mirror or extend desktop.")
                                ChecklistRow(number: "3", title: "Screen Distance", detail: "Position devices within 30 feet for stable low-latency transmission.")
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
                                    Label("Control Center Screen Mirroring", systemImage: "airplayvideo")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } else if selectedTab == 1 {
                        // Category 2: Wired Video (HDMI, DisplayPort, USB-C)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Wired Video (HDMI / DisplayPort / USB-C)", systemImage: "display.2")
                                    .font(.headline)
                                Spacer()
                                Text("Native Hardware Scan-Out")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundStyle(.orange)
                                    .cornerRadius(6)
                            }

                            Text("Connect any external computer monitor, television, or projector via HDMI, DisplayPort, or USB-C (Thunderbolt / DP Alternate Mode).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            // Active Monitors Detection Card
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Active Wired Displays:")
                                    .font(.subheadline)
                                    .fontWeight(.bold)

                                ForEach(manager.displays.filter { !$0.isBuiltIn && !$0.isSidecarOrAirPlay }) { ext in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(ext.displayName)
                                                .font(.headline)
                                            Text("\(ext.pointWidth)x\(ext.pointHeight) @ \(String(format: "%.0f", ext.currentRefreshRate))Hz | \(ext.connectionBus)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("ACTIVE")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.green)
                                    }
                                    .padding(10)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(8)
                                }

                                if manager.displays.filter({ !$0.isBuiltIn && !$0.isSidecarOrAirPlay }).isEmpty {
                                    Text("No wired external monitors currently detected. Plug in your HDMI/DisplayPort cable or USB-C hub.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Wired Monitor Connection Tips:")
                                    .font(.subheadline)
                                    .fontWeight(.bold)

                                ChecklistRow(number: "1", title: "Direct Cable / Hub", detail: "Use a USB-C to HDMI 2.0/2.1 or DisplayPort 1.4 cable for high refresh rates (up to 100Hz/144Hz).")
                                ChecklistRow(number: "2", title: "Monitor Input Selector", detail: "Ensure the physical monitor is switched to the active HDMI or DisplayPort input channel.")
                                ChecklistRow(number: "3", title: "Clamshell Dual Monitors", detail: "On M3 MacBook Air, close the laptop lid to drive two external monitors simultaneously.")
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(10)

                            Button {
                                manager.refreshDisplays()
                            } label: {
                                Label("Refresh & Scan Ports", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        // Category 3: USB Adapters & Virtual Displays
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("USB Adapters & Virtual Headless Displays", systemImage: "cpu")
                                    .font(.headline)
                                Spacer()
                                Text("DisplayLink & DriverKit")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.purple.opacity(0.15))
                                    .foregroundStyle(.purple)
                                    .cornerRadius(6)
                            }

                            Text("Bypass Apple Silicon external monitor hardware limits or connect USB-based display controllers, portable monitors, and virtual headless screens.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Supported Hardware & Adapters:")
                                    .font(.subheadline)
                                    .fontWeight(.bold)

                                ChecklistRow(number: "1", title: "DisplayLink USB Adapters", detail: "Enables driving 2 or 3 external monitors on M1/M2 MacBook Air via USB data compression.")
                                ChecklistRow(number: "2", title: "Silicon Motion (SMI) Hubs", detail: "Plug-and-play USB to dual-HDMI graphics converters with DriverKit acceleration.")
                                ChecklistRow(number: "3", title: "High-Speed USB Tablet Mode", detail: "Direct USB-C to USB-C cable connection for zero-latency tablet display extension.")
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(10)

                            HStack(spacing: 12) {
                                Button {
                                    sidecarService.openSystemAddDisplaySettings()
                                } label: {
                                    Label("Open macOS Displays (+)", systemImage: "plus.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    manager.refreshDisplays()
                                } label: {
                                    Label("Refresh All Buses", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.bordered)
                            }
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
        .frame(width: 620, height: 580)
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

