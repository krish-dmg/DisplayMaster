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
                    // Re-enable if disabled by OS timeout
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

    private func processMouseMove(event: CGEvent) {
        let displays = DisplayManager.shared.displays
        guard displays.count >= 2 else { return }

        let point = event.location
        let deltaX = event.getDoubleValueField(.mouseEventDeltaX)
        let deltaY = event.getDoubleValueField(.mouseEventDeltaY)

        // Find which display currently contains this point
        guard let sourceDisplay = displays.first(where: { $0.bounds.contains(point) }) else {
            return
        }

        let edgeThreshold: CGFloat = 4.0
        let sBounds = sourceDisplay.bounds

        // Check Left Edge crossing
        if deltaX < -0.1 && (point.x - sBounds.minX) <= edgeThreshold {
            // Find display immediately to the left
            let candidates = displays.filter {
                $0.id != sourceDisplay.id &&
                abs($0.bounds.maxX - sBounds.minX) <= 20.0
            }
            if let target = candidates.first {
                // If point.y is outside the target vertical bounds (dead wall zone!)
                if point.y < target.bounds.minY || point.y > target.bounds.maxY {
                    warpCursorAcrossHorizontal(
                        currentPoint: point,
                        source: sourceDisplay,
                        target: target,
                        targetX: target.bounds.maxX - 4
                    )
                    return
                }
            }
        }

        // Check Right Edge crossing
        if deltaX > 0.1 && (sBounds.maxX - point.x) <= edgeThreshold {
            let candidates = displays.filter {
                $0.id != sourceDisplay.id &&
                abs($0.bounds.minX - sBounds.maxX) <= 20.0
            }
            if let target = candidates.first {
                if point.y < target.bounds.minY || point.y > target.bounds.maxY {
                    warpCursorAcrossHorizontal(
                        currentPoint: point,
                        source: sourceDisplay,
                        target: target,
                        targetX: target.bounds.minX + 4
                    )
                    return
                }
            }
        }

        // Check Top Edge crossing
        if deltaY < -0.1 && (point.y - sBounds.minY) <= edgeThreshold {
            let candidates = displays.filter {
                $0.id != sourceDisplay.id &&
                abs($0.bounds.maxY - sBounds.minY) <= 20.0
            }
            if let target = candidates.first {
                if point.x < target.bounds.minX || point.x > target.bounds.maxX {
                    warpCursorAcrossVertical(
                        currentPoint: point,
                        source: sourceDisplay,
                        target: target,
                        targetY: target.bounds.maxY - 4
                    )
                    return
                }
            }
        }

        // Check Bottom Edge crossing
        if deltaY > 0.1 && (sBounds.maxY - point.y) <= edgeThreshold {
            let candidates = displays.filter {
                $0.id != sourceDisplay.id &&
                abs($0.bounds.minY - sBounds.maxY) <= 20.0
            }
            if let target = candidates.first {
                if point.x < target.bounds.minX || point.x > target.bounds.maxX {
                    warpCursorAcrossVertical(
                        currentPoint: point,
                        source: sourceDisplay,
                        target: target,
                        targetY: target.bounds.minY + 4
                    )
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
            targetY = min(max(currentPoint.y, target.bounds.minY + 4), target.bounds.maxY - 4)
        }

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
            targetX = min(max(currentPoint.x, target.bounds.minX + 4), target.bounds.maxX - 4)
        }

        let newPoint = CGPoint(x: targetX, y: targetY)
        isWarping = true
        CGWarpMouseCursorPosition(newPoint)
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        isWarping = false
    }
}
