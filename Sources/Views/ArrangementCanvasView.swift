import SwiftUI
import AppKit

public struct SmartGuide: Identifiable {
    public let id = UUID()
    public let isHorizontal: Bool
    public let position: CGFloat // Canvas coordinate (X if vertical, Y if horizontal)
    public let label: String
    public let start: CGFloat
    public let end: CGFloat
}

public struct ArrangementCanvasView: View {
    @ObservedObject var manager: DisplayManager
    @ObservedObject var cursorBridge = CursorBridgeService.shared

    @State private var stagedPositions: [CGDirectDisplayID: CGPoint] = [:]
    @State private var draggingDisplayID: CGDirectDisplayID? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var activeGuides: [SmartGuide] = []
    @State private var isApplying: Bool = false
    @State private var normalizeCanvasHeights: Bool = false

    public init(manager: DisplayManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Display Arrangement")
                            .font(.title2)
                            .fontWeight(.bold)

                        if cursorBridge.isEnabled {
                            HStack(spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("Seamless Cursor Crossing ON")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(4)
                        }
                    }

                    Text("Drag displays to position. Smart alignment guides show center, top, and edge snapping.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    // Equal Height View Toggle
                    Toggle(isOn: $normalizeCanvasHeights) {
                        Label("Equalize Visual Heights", systemImage: "rectangle.compress.vertical")
                            .font(.caption)
                    }
                    .toggleStyle(.button)

                    Menu {
                        Button("MacBook Center Wing Preset") {
                            autoArrangeMacBookCenter()
                        }
                        Button("Auto Align (Left to Right)") {
                            autoArrangeHorizontal()
                        }
                        Button("Align Center Y (Middle Level)") {
                            alignAllCenterY()
                        }
                        Button("Align Top Edges") {
                            alignAllTopEdges()
                        }
                    } label: {
                        Label("Presets & Align", systemImage: "rectangle.3.group")
                    }
                    .menuStyle(.borderedButton)

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

            // Seamless Cursor Bridge Banner
            HStack(spacing: 12) {
                Image(systemName: "cursorarrow.and.square.on.square.dashed")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Seamless Edge Crossing (Dead Wall Fix):")
                            .font(.caption)
                            .fontWeight(.bold)

                        Text(cursorBridge.isEnabled ? "Active" : "Disabled")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(cursorBridge.isEnabled ? .green : .secondary)
                    }

                    Text("Allows mouse to cross effortlessly between iPad Pro, MacBook Air, and Zebronics monitor from the dead top or dead bottom without hitting borders.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Mode", selection: $cursorBridge.mode) {
                    ForEach(CursorBridgeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 250)

                Toggle("", isOn: $cursorBridge.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))

            Divider()

            // Visual Canvas Area
            GeometryReader { geometry in
                let scale = calculateCanvasScale(geometrySize: geometry.size)
                let canvasOffset = calculateCanvasOffset(geometrySize: geometry.size, scale: scale)

                ZStack {
                    // Canvas grid
                    CanvasBackgroundGrid()

                    // Smart Alignment Guide Lines (Figma / Photoshop style)
                    ForEach(activeGuides) { guide in
                        if guide.isHorizontal {
                            // Horizontal guide line
                            let yPos = (guide.position * scale) + canvasOffset.y
                            ZStack {
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: yPos))
                                    path.addLine(to: CGPoint(x: geometry.size.width, y: yPos))
                                }
                                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .shadow(color: Color.cyan.opacity(0.4), radius: 2)

                                // Guide Label Badge
                                Text(guide.label)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.cyan)
                                    .foregroundStyle(.black)
                                    .cornerRadius(3)
                                    .position(x: geometry.size.width / 2, y: yPos - 10)
                            }
                        } else {
                            // Vertical guide line
                            let xPos = (guide.position * scale) + canvasOffset.x
                            ZStack {
                                Path { path in
                                    path.move(to: CGPoint(x: xPos, y: 0))
                                    path.addLine(to: CGPoint(x: xPos, y: geometry.size.height))
                                }
                                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .shadow(color: Color.cyan.opacity(0.4), radius: 2)

                                Text(guide.label)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.cyan)
                                    .foregroundStyle(.black)
                                    .cornerRadius(3)
                                    .position(x: xPos + 25, y: 20)
                            }
                        }
                    }

                    // Render Displays
                    ForEach(manager.displays) { display in
                        let currentOrigin = stagedPositions[display.id] ?? display.bounds.origin
                        let effectiveOrigin = (draggingDisplayID == display.id)
                            ? CGPoint(x: currentOrigin.x + (dragOffset.width / scale),
                                      y: currentOrigin.y + (dragOffset.height / scale))
                            : currentOrigin

                        let effectiveHeight = normalizeCanvasHeights ? 1050.0 : CGFloat(display.pointHeight)
                        let effectiveWidth = normalizeCanvasHeights
                            ? (effectiveHeight * display.aspectRatio)
                            : CGFloat(display.pointWidth)

                        let cardWidth = effectiveWidth * scale
                        let cardHeight = effectiveHeight * scale

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

                                    let deltaX = value.translation.width / scale
                                    let deltaY = value.translation.height / scale
                                    let livePos = CGPoint(x: currentOrigin.x + deltaX, y: currentOrigin.y + deltaY)

                                    // Compute live smart alignment guides
                                    let (_, guides) = calculateSmartAlignment(for: display, rawOrigin: livePos)
                                    activeGuides = guides
                                }
                                .onEnded { value in
                                    let deltaX = value.translation.width / scale
                                    let deltaY = value.translation.height / scale
                                    let rawNewOrigin = CGPoint(
                                        x: currentOrigin.x + deltaX,
                                        y: currentOrigin.y + deltaY
                                    )

                                    let (snappedOrigin, _) = calculateSmartAlignment(for: display, rawOrigin: rawNewOrigin)
                                    stagedPositions[display.id] = snappedOrigin
                                    draggingDisplayID = nil
                                    dragOffset = .zero
                                    activeGuides = []
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

            // Footer
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
                    Text("Drag displays near another to trigger Center, Top, Bottom, and Edge snapping guides.")
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
        activeGuides = []
        manager.statusMessage = "Arrangement reset to current layout."
    }

    private func autoArrangeHorizontal() {
        guard !manager.displays.isEmpty else { return }

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

    private func autoArrangeMacBookCenter() {
        guard !manager.displays.isEmpty else { return }

        let builtIn = manager.displays.first(where: { $0.isBuiltIn }) ?? manager.displays[0]
        var newPositions: [CGDirectDisplayID: CGPoint] = [:]
        newPositions[builtIn.id] = CGPoint(x: 0, y: 0)

        let others = manager.displays.filter { $0.id != builtIn.id }
        if others.count == 1 {
            // External to right, center aligned
            let diffY = (CGFloat(builtIn.pointHeight) - CGFloat(others[0].pointHeight)) / 2
            newPositions[others[0].id] = CGPoint(x: CGFloat(builtIn.pointWidth), y: diffY)
        } else if others.count >= 2 {
            // iPad to left, Zebronics to right, both center Y aligned!
            let leftDiffY = (CGFloat(builtIn.pointHeight) - CGFloat(others[0].pointHeight)) / 2
            let rightDiffY = (CGFloat(builtIn.pointHeight) - CGFloat(others[1].pointHeight)) / 2
            newPositions[others[0].id] = CGPoint(x: -CGFloat(others[0].pointWidth), y: leftDiffY)
            newPositions[others[1].id] = CGPoint(x: CGFloat(builtIn.pointWidth), y: rightDiffY)

            var curX = CGFloat(builtIn.pointWidth) + CGFloat(others[1].pointWidth)
            for d in others.dropFirst(2) {
                newPositions[d.id] = CGPoint(x: curX, y: 0)
                curX += CGFloat(d.pointWidth)
            }
        }

        stagedPositions = newPositions
        manager.statusMessage = "Preset applied: MacBook Center with iPad Left & Zebronics Right (Centered Level)."
    }

    private func alignAllCenterY() {
        guard !manager.displays.isEmpty else { return }
        let main = manager.displays.first(where: { $0.isMain }) ?? manager.displays[0]
        let mainCenterY = (stagedPositions[main.id]?.y ?? main.bounds.origin.y) + (CGFloat(main.pointHeight) / 2)

        var updated = stagedPositions
        for d in manager.displays {
            let currentX = updated[d.id]?.x ?? d.bounds.origin.x
            let targetY = mainCenterY - (CGFloat(d.pointHeight) / 2)
            updated[d.id] = CGPoint(x: currentX, y: targetY)
        }
        stagedPositions = updated
        manager.statusMessage = "All monitors aligned to common Center Y level."
    }

    private func alignAllTopEdges() {
        guard !manager.displays.isEmpty else { return }
        let main = manager.displays.first(where: { $0.isMain }) ?? manager.displays[0]
        let mainTopY = (stagedPositions[main.id]?.y ?? main.bounds.origin.y)

        var updated = stagedPositions
        for d in manager.displays {
            let currentX = updated[d.id]?.x ?? d.bounds.origin.x
            updated[d.id] = CGPoint(x: currentX, y: mainTopY)
        }
        stagedPositions = updated
        manager.statusMessage = "All monitor top edges aligned."
    }

    // Figma / Photoshop style Smart Guide Calculation
    private func calculateSmartAlignment(for display: DisplayInfo, rawOrigin: CGPoint) -> (CGPoint, [SmartGuide]) {
        var snapped = rawOrigin
        let snapThreshold: CGFloat = 18.0
        var guides: [SmartGuide] = []

        let dWidth = CGFloat(display.pointWidth)
        let dHeight = CGFloat(display.pointHeight)
        let dCenterY = rawOrigin.y + (dHeight / 2)
        let dCenterX = rawOrigin.x + (dWidth / 2)

        for other in manager.displays where other.id != display.id {
            let otherOrigin = stagedPositions[other.id] ?? other.bounds.origin
            let oWidth = CGFloat(other.pointWidth)
            let oHeight = CGFloat(other.pointHeight)
            let oCenterY = otherOrigin.y + (oHeight / 2)
            let oCenterX = otherOrigin.x + (oWidth / 2)

            // 1. Top Edge Alignment
            if abs(snapped.y - otherOrigin.y) < snapThreshold {
                snapped.y = otherOrigin.y
                guides.append(SmartGuide(
                    isHorizontal: true,
                    position: otherOrigin.y,
                    label: "TOP ALIGN",
                    start: min(snapped.x, otherOrigin.x),
                    end: max(snapped.x + dWidth, otherOrigin.x + oWidth)
                ))
            }

            // 2. Center Y (Middle Level) Alignment
            if abs(dCenterY - oCenterY) < snapThreshold {
                snapped.y = oCenterY - (dHeight / 2)
                guides.append(SmartGuide(
                    isHorizontal: true,
                    position: oCenterY,
                    label: "CENTER LEVEL",
                    start: min(snapped.x, otherOrigin.x),
                    end: max(snapped.x + dWidth, otherOrigin.x + oWidth)
                ))
            }

            // 3. Bottom Edge Alignment
            let targetBottom = otherOrigin.y + oHeight
            if abs((snapped.y + dHeight) - targetBottom) < snapThreshold {
                snapped.y = targetBottom - dHeight
                guides.append(SmartGuide(
                    isHorizontal: true,
                    position: targetBottom,
                    label: "BOTTOM ALIGN",
                    start: min(snapped.x, otherOrigin.x),
                    end: max(snapped.x + dWidth, otherOrigin.x + oWidth)
                ))
            }

            // 4. Horizontal Edge Touching (Left of other)
            let targetLeftTouch = otherOrigin.x - dWidth
            if abs(snapped.x - targetLeftTouch) < snapThreshold {
                snapped.x = targetLeftTouch
                guides.append(SmartGuide(
                    isHorizontal: false,
                    position: otherOrigin.x,
                    label: "EDGE SNAP",
                    start: min(snapped.y, otherOrigin.y),
                    end: max(snapped.y + dHeight, otherOrigin.y + oHeight)
                ))
            }

            // 5. Horizontal Edge Touching (Right of other)
            let targetRightTouch = otherOrigin.x + oWidth
            if abs(snapped.x - targetRightTouch) < snapThreshold {
                snapped.x = targetRightTouch
                guides.append(SmartGuide(
                    isHorizontal: false,
                    position: targetRightTouch,
                    label: "EDGE SNAP",
                    start: min(snapped.y, otherOrigin.y),
                    end: max(snapped.y + dHeight, otherOrigin.y + oHeight)
                ))
            }

            // 6. Center X Alignment (for vertical stacking)
            if abs(dCenterX - oCenterX) < snapThreshold {
                snapped.x = oCenterX - (dWidth / 2)
                guides.append(SmartGuide(
                    isHorizontal: false,
                    position: oCenterX,
                    label: "CENTER X",
                    start: min(snapped.y, otherOrigin.y),
                    end: max(snapped.y + dHeight, otherOrigin.y + oHeight)
                ))
            }
        }

        return (snapped, guides)
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
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.85), value: isDragging)
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
