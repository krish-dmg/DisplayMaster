import AppKit
import SwiftUI

public final class ScreenIdentifierOverlay {
    public static let shared = ScreenIdentifierOverlay()
    private var activeWindows: [NSWindow] = []

    private init() {}

    @MainActor
    public func flash(displayID: CGDirectDisplayID, displayName: String) {
        // Find matching NSScreen
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
        }) else { return }

        let screenFrame = screen.frame
        let windowWidth: CGFloat = 360
        let windowHeight: CGFloat = 160
        let windowRect = NSRect(
            x: screenFrame.midX - (windowWidth / 2),
            y: screenFrame.midY - (windowHeight / 2),
            width: windowWidth,
            height: windowHeight
        )

        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = true

        let rootView = NSHostingView(
            rootView: ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.6), lineWidth: 2)
                    )
                VStack(spacing: 8) {
                    Text("DISPLAY IDENTIFIER")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(displayName)
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text("Display ID: \(displayID)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
            }
        )

        window.contentView = rootView
        window.makeKeyAndOrderFront(nil)
        activeWindows.append(window)

        // Animate fade out after 1.4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak window, weak self] in
            guard let window = window else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                window.animator().alphaValue = 0.0
            }, completionHandler: {
                window.orderOut(nil)
                self?.activeWindows.removeAll(where: { $0 == window })
            })
        }
    }
}
