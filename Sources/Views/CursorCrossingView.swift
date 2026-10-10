import SwiftUI

public struct CursorCrossingView: View {
    @ObservedObject var cursorBridge = CursorBridgeService.shared
    @ObservedObject var manager = DisplayManager.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seamless Cursor Crossing (Dead Wall Fix)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Eliminates invisible boundary walls between different-sized screens (iPad Pro, MacBook Air, and Zebronics monitor).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Master Toggle Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Enable Seamless Crossing")
                                .font(.headline)
                            Text("Automatically translates cursor coordinates when crossing between displays with differing vertical heights.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("", isOn: $cursorBridge.isEnabled)
                            .toggleStyle(.switch)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Crossing Translation Mode:")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Picker("Mode", selection: $cursorBridge.mode) {
                            ForEach(CursorBridgeMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // The Problem & Solution Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Label("How It Works Behind The Scenes", systemImage: "questionmark.circle")
                        .font(.headline)

                    Text("Why standard macOS gets stuck:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Your MacBook Air screen is 1,050 points tall (y: 0 to 1,050). Your iPad Pro is 970 points tall (y: 0 to 970). When your cursor moves left on the bottom 80 pixels of the MacBook screen (y > 970), macOS encounters an empty void because the iPad does not exist at that vertical coordinate. The mouse halts against an invisible dead wall.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("The DisplayMaster Solution:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("DisplayMaster continuously monitors screen edge transitions. When you drag your mouse towards an adjacent shorter monitor:")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("- Proportional Mode: Matches top-to-top and bottom-to-bottom mathematically (y_target = y_source / source_height * target_height). Moving across at the dead bottom of the MacBook smoothly puts you at the dead bottom of the iPad Pro.")
                        Text("- Edge Slide Mode: Clamps your cursor to the closest active edge pixel on the neighboring screen, ensuring zero resistance.")
                    }
                    .font(.body)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // Current Display Bounds Diagnostic
                VStack(alignment: .leading, spacing: 10) {
                    Label("Current Display Geometry", systemImage: "ruler")
                        .font(.headline)

                    ForEach(manager.displays) { d in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.displayName)
                                    .fontWeight(.medium)
                                Text("Bounds: Origin (\(Int(d.bounds.minX)), \(Int(d.bounds.minY))) | Size: \(Int(d.bounds.width)) x \(Int(d.bounds.height)) pt")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(d.recognizedType.badgeLabel)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 4)
                        if d.id != manager.displays.last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
    }
}
