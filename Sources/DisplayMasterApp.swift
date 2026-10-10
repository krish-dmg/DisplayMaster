import SwiftUI
import AppKit

@main
struct DisplayMasterApp: App {
    var body: some Scene {
        WindowGroup("DisplayMaster") {
            MainContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Displays") {
                Button("Refresh Displays") {
                    DisplayManager.shared.refreshDisplays()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Identify All Displays") {
                    for d in DisplayManager.shared.displays {
                        DisplayManager.shared.identifyDisplay(displayID: d.id)
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
    }
}
