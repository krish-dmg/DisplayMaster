import Foundation
import CoreGraphics
import AppKit
import Combine

public enum CursorBridgeMode: String, CaseIterable, Identifiable {
    case proportional = "Proportional (Top-to-Top, Bottom-to-Bottom)"
    case clamp = "Edge Slide (Slide to Nearest Pixel)"

    public var id: String { rawValue }
}

@MainActor
public final class CursorBridgeService: ObservableObject {
    public static let shared = CursorBridgeService()

    @Published public var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "DisplayMaster_CursorBridgeEnabled")
            updateTapState()
        }
    }

    @Published public var mode: CursorBridgeMode = .proportional {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "DisplayMaster_CursorBridgeMode")
        }
    }

    private var eventPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isWarping: Bool = false
    private var lastWarpTime: TimeInterval = 0

    private init() {
        if let savedEnabled = UserDefaults.standard.object(forKey: "DisplayMaster_CursorBridgeEnabled") as? Bool {
            self.isEnabled = savedEnabled
        }
        if let savedMode = UserDefaults.standard.string(forKey: "DisplayMaster_CursorBridgeMode"),
           let parsedMode = CursorBridgeMode(rawValue: savedMode) {
            self.mode = parsedMode
        }

        setupTap()
    }

    private func setupTap() {
        guard eventPort == nil else { return }

        let mask = (1 << CGEventType.mouseMoved.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<CursorBridgeService>.fromOpaque(refcon).takeUnretainedValue()

                if type.rawValue == 0xFFFFFFFF || type == .tapDisabledByTimeout {
                    if let port = service.eventPort {
                        CGEvent.tapEnable(tap: port, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }

                if service.isEnabled && !service.isWarping {
                    service.processMouseMove(event: event)
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        )

        guard let tapPort = tap else {
            return
        }

        self.eventPort = tapPort
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tapPort, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tapPort, enable: isEnabled)
    }

    private func updateTapState() {
        if let port = eventPort {
            CGEvent.tapEnable(tap: port, enable: isEnabled)
        } else if isEnabled {
            setupTap()
        }
    }

    private func distanceToRect(point: CGPoint, rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return sqrt(dx * dx + dy * dy)
    }

    private func findSourceDisplay(point: CGPoint, deltaX: Double, deltaY: Double, displays: [DisplayInfo]) -> DisplayInfo? {
        // Priority 1: When moving horizontally near a vertical boundary
        if deltaX > 0.05 {
            // Moving right: if cursor is near maxX of a display, that display is the source
            if let match = displays.first(where: {
                abs($0.bounds.maxX - point.x) <= 16.0 &&
                point.y >= ($0.bounds.minY - 30) && point.y <= ($0.bounds.maxY + 30)
            }) {
                return match
            }
        } else if deltaX < -0.05 {
            // Moving left: if cursor is near minX of a display, that display is the source
            if let match = displays.first(where: {
                abs(point.x - $0.bounds.minX) <= 16.0 &&
                point.y >= ($0.bounds.minY - 30) && point.y <= ($0.bounds.maxY + 30)
            }) {
                return match
            }
        }

        // Priority 2: When moving vertically near a horizontal boundary
        if deltaY > 0.05 {
            // Moving down: if cursor is near maxY of a display
            if let match = displays.first(where: {
                abs($0.bounds.maxY - point.y) <= 16.0 &&
                point.x >= ($0.bounds.minX - 30) && point.x <= ($0.bounds.maxX + 30)
            }) {
                return match
            }
        } else if deltaY < -0.05 {
            // Moving up: if cursor is near minY of a display
            if let match = displays.first(where: {
                abs(point.y - $0.bounds.minY) <= 16.0 &&
                point.x >= ($0.bounds.minX - 30) && point.x <= ($0.bounds.maxX + 30)
            }) {
                return match
            }
        }

        // Priority 3: Exact or slightly inset bounding box
        if let match = displays.first(where: { $0.bounds.insetBy(dx: -3, dy: -3).contains(point) }) {
            return match
        }

        // Priority 4: Closest display to point
        return displays.min(by: { d1, d2 in
            distanceToRect(point: point, rect: d1.bounds) < distanceToRect(point: point, rect: d2.bounds)
        })
    }

    private func processMouseMove(event: CGEvent) {
        let displays = DisplayManager.shared.displays
        guard displays.count >= 2 else { return }

        let now = Date().timeIntervalSince1970
        guard (now - lastWarpTime) > 0.04 else { return }

        let point = event.location
        let deltaX = event.getDoubleValueField(.mouseEventDeltaX)
        let deltaY = event.getDoubleValueField(.mouseEventDeltaY)

        guard let sourceDisplay = findSourceDisplay(point: point, deltaX: deltaX, deltaY: deltaY, displays: displays) else {
            return
        }

        let edgeThreshold: CGFloat = 12.0
        let sBounds = sourceDisplay.bounds

        // 1. Check Left Edge crossing: cursor is at left boundary moving left
        if deltaX < -0.05 && (point.x - sBounds.minX) <= edgeThreshold {
            let candidates = displays.filter {
                $0.id != sourceDisplay.id &&
                abs($0.bounds.maxX - sBounds.minX) <= 50.0
            }
            if let target = candidates.first {
                let isDeadZone = (point.y < target.bounds.minY || point.y > target.bounds.maxY)
                let isStickyTopCorner = (point.y - sBounds.minY) <= 50.0 // Apple menu bar friction zone
                let isStickyBottomCorner = (sBounds.maxY - point.y) <= 50.0
                let isIntentionalCrossing = deltaX < -0.15

                if isDeadZone || isStickyTopCorner || isStickyBottomCorner || isIntentionalCrossing {
                    warpCursorAcrossHorizontal(
                        currentPoint: point,
                        source: sourceDisplay,
                        target: target,
                        targetX: target.bounds.maxX - 16
                    )
                    lastWarpTime = now
                    return
                }
            }
        }

        // 2. Check Right Edge crossing: cursor is at right boundary moving right
        if deltaX > 0.05 && (sBounds.maxX - point.x) <= edgeThreshold {
            let candidates = displays.filter {
                $0.id != sourceDisplay.id &&
                abs($0.bounds.minX - sBounds.maxX) <= 50.0
            }
            if let target = candidates.first {
                let isDeadZone = (point.y < target.bounds.minY || point.y > target.bounds.maxY)
                let isStickyTopCorner = (point.y - sBounds.minY) <= 50.0 // Control center corner friction zone
                let isStickyBottomCorner = (sBounds.maxY - point.y) <= 50.0
                let isIntentionalCrossing = deltaX > 0.15

                if isDeadZone || isStickyTopCorner || isStickyBottomCorner || isIntentionalCrossing {
                    warpCursorAcrossHorizontal(
                        currentPoint: point,
                        source: sourceDisplay,
                        target: target,
                        targetX: target.bounds.minX + 16
                    )
                    lastWarpTime = now
                    return
                }
            }
        }

        // 3. Check Top Edge crossing: cursor is at top boundary moving up
        if deltaY < -0.05 && (point.y - sBounds.minY) <= edgeThreshold {
            let candidates = displays.filter {
                $0.id != sourceDisplay.id &&
                abs($0.bounds.maxY - sBounds.minY) <= 50.0
            }
            if let target = candidates.first {
                let isDeadZone = (point.x < target.bounds.minX || point.x > target.bounds.maxX)
                let isCorner = (point.x - sBounds.minX) <= 50.0 || (sBounds.maxX - point.x) <= 50.0
                let isIntentionalCrossing = deltaY < -0.15

                if isDeadZone || isCorner || isIntentionalCrossing {
                    warpCursorAcrossVertical(
                        currentPoint: point,
                        source: sourceDisplay,
                        target: target,
                        targetY: target.bounds.maxY - 16
                    )
                    lastWarpTime = now
                    return
                }
            }
        }

        // 4. Check Bottom Edge crossing: cursor is at bottom boundary moving down
        if deltaY > 0.05 && (sBounds.maxY - point.y) <= edgeThreshold {
            let candidates = displays.filter {
                $0.id != sourceDisplay.id &&
                abs($0.bounds.minY - sBounds.maxY) <= 50.0
            }
            if let target = candidates.first {
                let isDeadZone = (point.x < target.bounds.minX || point.x > target.bounds.maxX)
                let isCorner = (point.x - sBounds.minX) <= 50.0 || (sBounds.maxX - point.x) <= 50.0
                let isIntentionalCrossing = deltaY > 0.15

                if isDeadZone || isCorner || isIntentionalCrossing {
                    warpCursorAcrossVertical(
                        currentPoint: point,
                        source: sourceDisplay,
                        target: target,
                        targetY: target.bounds.minY + 16
                    )
                    lastWarpTime = now
                    return
                }
            }
        }
    }

    private func warpCursorAcrossHorizontal(
        currentPoint: CGPoint,
        source: DisplayInfo,
        target: DisplayInfo,
        targetX: CGFloat
    ) {
        var targetY: CGFloat = currentPoint.y

        if mode == .proportional {
            let sourceHeight = max(source.bounds.height, 1)
            let relativeProgress = (currentPoint.y - source.bounds.minY) / sourceHeight
            targetY = target.bounds.minY + (relativeProgress * target.bounds.height)
        } else {
            targetY = min(max(currentPoint.y, target.bounds.minY + 6), target.bounds.maxY - 6)
        }

        // Keep within safe target vertical bounds
        targetY = min(max(targetY, target.bounds.minY + 6), target.bounds.maxY - 6)

        let newPoint = CGPoint(x: targetX, y: targetY)
        isWarping = true
        CGWarpMouseCursorPosition(newPoint)
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        isWarping = false
    }

    private func warpCursorAcrossVertical(
        currentPoint: CGPoint,
        source: DisplayInfo,
        target: DisplayInfo,
        targetY: CGFloat
    ) {
        var targetX: CGFloat = currentPoint.x

        if mode == .proportional {
            let sourceWidth = max(source.bounds.width, 1)
            let relativeProgress = (currentPoint.x - source.bounds.minX) / sourceWidth
            targetX = target.bounds.minX + (relativeProgress * target.bounds.width)
        } else {
            targetX = min(max(currentPoint.x, target.bounds.minX + 6), target.bounds.maxX - 6)
        }

        targetX = min(max(targetX, target.bounds.minX + 6), target.bounds.maxX - 6)

        let newPoint = CGPoint(x: targetX, y: targetY)
        isWarping = true
        CGWarpMouseCursorPosition(newPoint)
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        isWarping = false
    }
}
