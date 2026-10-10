import SwiftUI

public struct ArchitectureResearchView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("macOS Display Subsystems & Architecture")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Comprehensive technical reference for wired, wireless, and deep-level display pipelines on Apple Silicon.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Section 1: Apple Silicon Hardware Pipelines
                ArchitectureCard(
                    title: "1. Apple Silicon Hardware Display Pipelines",
                    icon: "cpu",
                    badge: "Hardware & DCP"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Apple Silicon Macs utilize an integrated Display Coprocessor (DCP) and dedicated GPU display scan-out engines. Unlike Intel Macs with discrete GPUs or multiplexers:")
                        Text("- MacBook Air (M1 & M2): Native hardware pipeline contains 2 display heads. One is permanently hardwired to the internal eDP (embedded DisplayPort) Liquid Retina panel. The second head drives the external USB-C / Thunderbolt port (supporting up to 6K @ 60Hz).")
                        Text("- MacBook Air (M3): Native hardware pipeline allows driving two external displays simultaneously, but requires the laptop lid to be closed (Clamshell mode) because the internal scan-out engine is re-routed to the secondary external port.")
                        Text("- DisplayLink / Silicon Motion: Bypasses native display limits by encoding desktop framebuffers into compressed USB data packets and sending them to an external hardware controller, decoded via a DriverKit dext.")
                    }
                    .font(.body)
                }

                // Section 2: External Monitors (Zebronics, HDMI, DDC/CI)
                ArchitectureCard(
                    title: "2. External Monitors (HDMI, DisplayPort, DDC/CI)",
                    icon: "display",
                    badge: "Wired Video"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("When connecting an external monitor (such as your Zebronics monitor via HDMI):")
                        Text("- Video Signaling: macOS outputs DisplayPort 1.4 Alternate Mode over USB-C. Dongles convert this using an active LSPCon (Level Shifter and Protocol Converter) to HDMI 2.0/2.1 TMDS or FRL signals.")
                        Text("- EDID Handshake: During plug-in, macOS reads the 128/256-byte EDID (Extended Display Identification Data) block over the I2C bus to determine native resolutions, refresh rates (such as your 100Hz mode), and color matrices.")
                        Text("- DDC/CI Hardware Control: The I2C lines can carry MCCS (Monitor Control Command Set) packets. Utilities can send raw I2C payloads via IOKit (IOI2CInterface) to modify physical monitor hardware brightness, contrast, and input sources.")
                    }
                    .font(.body)
                }

                // Section 3: iPad Pro 2018 & Wireless Displays
                ArchitectureCard(
                    title: "3. iPad Pro (Sidecar & AirPlay 2 Architecture)",
                    icon: "ipad.landscape",
                    badge: "Wireless & VideoToolbox"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sidecar connects your iPad Pro 2018 as an ultra-low-latency display extension:")
                        Text("- Transport: Operates over direct USB-C cable (high-throughput multiplexed USB channel) or wirelessly via AWDL (Apple Wireless Direct Link) peer-to-peer Wi-Fi with Bluetooth Low Energy discovery.")
                        Text("- Framebuffer Generation: macOS WindowServer creates a virtual display framebuffer. VideoToolbox hardware-encodes frames using H.264 / HEVC with real-time rate control (< 20ms round-trip latency).")
                        Text("- In CoreGraphics: Sidecar exposes a genuine CGDirectDisplayID. It integrates directly into the global desktop coordinates, allowing dragging windows and spatial positioning just like physical hardware.")
                        Text("- Universal Control vs Sidecar: Universal Control routes mouse and keyboard HID events across devices while each device runs its own OS. Sidecar treats the iPad as an external display buffer.")
                    }
                    .font(.body)
                }

                // Section 4: Deep Native Frameworks & APIs
                ArchitectureCard(
                    title: "4. Native macOS System APIs Used in DisplayMaster",
                    icon: "curlybraces",
                    badge: "APIs & Frameworks"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("- CoreGraphics Transactions: Multi-display arrangement uses CGBeginDisplayConfiguration, CGConfigureDisplayOrigin, and CGCompleteDisplayConfiguration to modify the global desktop matrix atomically without tearing.")
                        Text("- Display Modes: CGDisplayCopyAllDisplayModes with kCGDisplayShowDuplicateLowResolutionModes exposes both native HiDPI retina scalings and physical raw refresh rates (60Hz, 75Hz, 100Hz).")
                        Text("- ColorSync Management: ColorSyncDeviceSetCustomProfiles maps system ICC profiles (Display P3, Adobe RGB 1998, sRGB) directly to the display hardware UUID via the ColorSync subsystem.")
                        Text("- Real-time Hotplug: Observes NSApplication.didChangeScreenParametersNotification and CGDisplayRegisterReconfigurationCallback for instant responsiveness.")
                    }
                    .font(.body)
                }
            }
            .padding()
        }
    }
}

struct ArchitectureCard<Content: View>: View {
    let title: String
    let icon: String
    let badge: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)

                Spacer()

                Text(badge)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(6)
            }

            Divider()

            content()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}
