import SwiftUI
import AppKit

struct StagedDisplayPosition: Identifiable {
    let id: CGDirectDisplayID
    let display: DisplayInfo
    var origin: CGPoint
    var isDragging: Bool = false
}

public struct ArrangementCanvasView: View {
    @ObservedObject var manager: DisplayManager
    @State private var stagedPositions: [CGDirectDisplayID: CGPoint] = [:]
    @State private var draggingDisplayID: CGDirectDisplayID? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var isApplying: Bool = false

    public init(manager: DisplayManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Control Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Display Arrangement")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Drag monitors to match your physical desk layout. Changes take effect on apply.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        autoArrangeHorizontal()
                    } label: {
                        Label("Auto Align", systemImage: "rectangle.split.3x1")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        resetToCurrentLayout()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        for d in manager.displays {
                            manager.identifyDisplay(displayID: d.id)
                        }
                    } label: {
                        Label("Identify All", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        applyLayout()
                    } label: {
                        Label("Apply Layout", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isApplying || manager.displays.isEmpty)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Visual Canvas Area
            GeometryReader { geometry in
                let scale = calculateCanvasScale(geometrySize: geometry.size)
                let canvasOffset = calculateCanvasOffset(geometrySize: geometry.size, scale: scale)

                ZStack {
                    // Subtle background grid
                    CanvasBackgroundGrid()

                    // Render Displays
                    ForEach(manager.displays) { display in
                        let currentOrigin = stagedPositions[display.id] ?? display.bounds.origin
                        let effectiveOrigin = (draggingDisplayID == display.id)
                            ? CGPoint(x: currentOrigin.x + (dragOffset.width / scale),
                                      y: currentOrigin.y + (dragOffset.height / scale))
                            : currentOrigin

                        let cardWidth = CGFloat(display.pointWidth) * scale
                        let cardHeight = CGFloat(display.pointHeight) * scale

                        DisplayCanvasCard(
                            display: display,
                            isSelected: manager.selectedDisplayID == display.id,
                            isDragging: draggingDisplayID == display.id,
                            origin: effectiveOrigin,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight
                        )
                        .position(
                            x: (effectiveOrigin.x * scale) + (cardWidth / 2) + canvasOffset.x,
                            y: (effectiveOrigin.y * scale) + (cardHeight / 2) + canvasOffset.y
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if draggingDisplayID == nil {
                                        draggingDisplayID = display.id
                                        manager.selectedDisplayID = display.id
                                    }
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    let deltaX = value.translation.width / scale
                                    let deltaY = value.translation.height / scale
                                    let rawNewOrigin = CGPoint(
                                        x: currentOrigin.x + deltaX,
                                        y: currentOrigin.y + deltaY
                                    )

                                    // Snap to edges of adjacent monitors
                                    let snappedOrigin = snapOrigin(for: display, rawOrigin: rawNewOrigin)
                                    stagedPositions[display.id] = snappedOrigin
                                    draggingDisplayID = nil
                                    dragOffset = .zero
                                }
                        )
                        .onTapGesture {
                            manager.selectedDisplayID = display.id
                            manager.identifyDisplay(displayID: display.id)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .background(Color(nsColor: .underPageBackgroundColor))

            Divider()

            // Footer info bar
            HStack {
                Label("\(manager.displays.count) Active Displays Connected", systemImage: "display.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let status = manager.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if let error = manager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Tip: Click any monitor to select or identify it.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .onAppear {
            syncStagedPositions()
        }
        .onChange(of: manager.displays) {
            syncStagedPositions()
        }
    }

    private func syncStagedPositions() {
        var positions: [CGDirectDisplayID: CGPoint] = [:]
        for d in manager.displays {
            positions[d.id] = d.bounds.origin
        }
        stagedPositions = positions
    }

    private func resetToCurrentLayout() {
        syncStagedPositions()
        manager.statusMessage = "Arrangement reset to current layout."
    }

    private func autoArrangeHorizontal() {
        guard !manager.displays.isEmpty else { return }

        // Find main display, anchor it at (0, 0)
        var newPositions: [CGDirectDisplayID: CGPoint] = [:]
        let main = manager.displays.first(where: { $0.isMain }) ?? manager.displays[0]
        newPositions[main.id] = CGPoint(x: 0, y: 0)

        var currentX = CGFloat(main.pointWidth)
        for display in manager.displays where display.id != main.id {
            newPositions[display.id] = CGPoint(x: currentX, y: 0)
            currentX += CGFloat(display.pointWidth)
        }

        stagedPositions = newPositions
        manager.statusMessage = "Displays aligned horizontally side-by-side."
    }

    private func snapOrigin(for display: DisplayInfo, rawOrigin: CGPoint) -> CGPoint {
        var snapped = rawOrigin
        let snapTolerance: CGFloat = 40.0

        for other in manager.displays where other.id != display.id {
            let otherOrigin = stagedPositions[other.id] ?? other.bounds.origin
            let otherRight = otherOrigin.x + CGFloat(other.pointWidth)
            let otherBottom = otherOrigin.y + CGFloat(other.pointHeight)

            // Snap left edge to other right edge
            if abs(snapped.x - otherRight) < snapTolerance {
                snapped.x = otherRight
            }
            // Snap right edge to other left edge
            if abs((snapped.x + CGFloat(display.pointWidth)) - otherOrigin.x) < snapTolerance {
                snapped.x = otherOrigin.x - CGFloat(display.pointWidth)
            }
            // Snap top edge to other top edge
            if abs(snapped.y - otherOrigin.y) < snapTolerance {
                snapped.y = otherOrigin.y
            }
            // Snap top edge to other bottom edge
            if abs(snapped.y - otherBottom) < snapTolerance {
                snapped.y = otherBottom
            }
            // Snap bottom edge to other top edge
            if abs((snapped.y + CGFloat(display.pointHeight)) - otherOrigin.y) < snapTolerance {
                snapped.y = otherOrigin.y - CGFloat(display.pointHeight)
            }
        }

        return snapped
    }

    private func applyLayout() {
        isApplying = true
        defer { isApplying = false }

        do {
            try manager.applyArrangement(origins: stagedPositions)
        } catch {
            manager.errorMessage = error.localizedDescription
        }
    }

    private func calculateCanvasScale(geometrySize: CGSize) -> CGFloat {
        guard !manager.displays.isEmpty else { return 0.1 }

        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var minY: CGFloat = .infinity
        var maxY: CGFloat = -.infinity

        for d in manager.displays {
            let origin = stagedPositions[d.id] ?? d.bounds.origin
            minX = min(minX, origin.x)
            maxX = max(maxX, origin.x + CGFloat(d.pointWidth))
            minY = min(minY, origin.y)
            maxY = max(maxY, origin.y + CGFloat(d.pointHeight))
        }

        let totalWidth = max(maxX - minX, 100)
        let totalHeight = max(maxY - minY, 100)

        let margin: CGFloat = 80
        let scaleX = (geometrySize.width - margin) / totalWidth
        let scaleY = (geometrySize.height - margin) / totalHeight
        return max(min(scaleX, scaleY, 0.22), 0.04)
    }

    private func calculateCanvasOffset(geometrySize: CGSize, scale: CGFloat) -> CGPoint {
        guard !manager.displays.isEmpty else { return .zero }

        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var minY: CGFloat = .infinity
        var maxY: CGFloat = -.infinity

        for d in manager.displays {
            let origin = stagedPositions[d.id] ?? d.bounds.origin
            minX = min(minX, origin.x)
            maxX = max(maxX, origin.x + CGFloat(d.pointWidth))
            minY = min(minY, origin.y)
            maxY = max(maxY, origin.y + CGFloat(d.pointHeight))
        }

        let centerGlobalX = (minX + maxX) / 2
        let centerGlobalY = (minY + maxY) / 2

        let offsetX = (geometrySize.width / 2) - (centerGlobalX * scale)
        let offsetY = (geometrySize.height / 2) - (centerGlobalY * scale)

        return CGPoint(x: offsetX, y: offsetY)
    }
}

struct DisplayCanvasCard: View {
    let display: DisplayInfo
    let isSelected: Bool
    let isDragging: Bool
    let origin: CGPoint
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? Color.accentColor : Color.primary.opacity(0.2),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .shadow(color: Color.black.opacity(isDragging ? 0.35 : 0.15), radius: isDragging ? 12 : 5, x: 0, y: isDragging ? 6 : 2)

            VStack(spacing: 4) {
                // Top badges
                HStack(spacing: 4) {
                    if display.isMain {
                        Text("MAIN")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.25))
                            .cornerRadius(4)
                    }

                    Text(display.recognizedType.badgeLabel)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(display.recognizedType == .zebronicsExternal ? Color.orange.opacity(0.25) : (display.recognizedType == .sidecarIPad ? Color.purple.opacity(0.25) : Color.blue.opacity(0.2)))
                        .cornerRadius(4)
                }

                Text(display.displayName)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 6)

                Text("\(display.pointWidth)x\(display.pointHeight) @ \(String(format: "%.0f", display.currentRefreshRate))Hz")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text("(\(Int(round(origin.x))), \(Int(round(origin.y))))")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(6)
        }
        .frame(width: max(cardWidth, 120), height: max(cardHeight, 80))
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isDragging)
    }
}

struct CanvasBackgroundGrid: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let step: CGFloat = 30
                for x in stride(from: 0, through: geometry.size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                for y in stride(from: 0, through: geometry.size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        }
    }
}
