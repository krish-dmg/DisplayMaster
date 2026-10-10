import SwiftUI
import AppKit

enum NavigationItem: Hashable {
    case arrangement
    case display(CGDirectDisplayID)
    case architecture
}

public struct MainContentView: View {
    @StateObject private var manager = DisplayManager.shared
    @State private var selection: NavigationItem? = .arrangement

    public init() {}

    public var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Tools") {
                    NavigationLink(value: NavigationItem.arrangement) {
                        Label("Arrangement Canvas", systemImage: "square.split.2x2")
                    }

                    NavigationLink(value: NavigationItem.architecture) {
                        Label("Deep Architecture", systemImage: "book.pages")
                    }
                }

                Section("Connected Displays (\(manager.displays.count))") {
                    ForEach(manager.displays) { display in
                        NavigationLink(value: NavigationItem.display(display.id)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(display.name)
                                            .fontWeight(.medium)
                                        if display.isMain {
                                            Text("Main")
                                                .font(.system(size: 9, weight: .bold))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.accentColor.opacity(0.2))
                                                .cornerRadius(3)
                                        }
                                    }

                                    Text("\(display.pointWidth)x\(display.pointHeight) @ \(String(format: "%.0f", display.currentRefreshRate))Hz")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    manager.identifyDisplay(displayID: display.id)
                                } label: {
                                    Image(systemName: "macwindow.badge.plus")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help("Identify screen")
                            }
                        }
                    }
                }
            }
            .navigationTitle("DisplayMaster")
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        manager.refreshDisplays()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh active displays")
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("macOS Settings", systemImage: "gear")
                    }
                    .help("Open macOS Displays System Settings")
                }
            }
        } detail: {
            switch selection {
            case .arrangement, .none:
                ArrangementCanvasView(manager: manager)

            case .architecture:
                ArchitectureResearchView()

            case .display(let displayID):
                if let display = manager.displays.first(where: { $0.id == displayID }) {
                    DisplayInspectorView(manager: manager, display: display)
                } else {
                    ArrangementCanvasView(manager: manager)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
