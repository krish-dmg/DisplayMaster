import Foundation
import CoreGraphics
import AppKit

public struct HardwareSpecs: Hashable {
    public let modelIdentifier: String
    public let generation: String
    public let processorOrChipset: String
    public let panelTechnology: String
    public let physicalRefreshCapability: String
    public let connectionBus: String

    public init(
        modelIdentifier: String,
        generation: String,
        processorOrChipset: String,
        panelTechnology: String,
        physicalRefreshCapability: String,
        connectionBus: String
    ) {
        self.modelIdentifier = modelIdentifier
        self.generation = generation
        self.processorOrChipset = processorOrChipset
        self.panelTechnology = panelTechnology
        self.physicalRefreshCapability = physicalRefreshCapability
        self.connectionBus = connectionBus
    }
}

public enum RecognizedDisplayType: String, Codable {
    case builtInRetina = "Built-in Retina Display"
    case zebronicsExternal = "Zebronics External Monitor"
    case sidecarIPad = "iPad Pro (Sidecar)"
    case genericExternal = "External Monitor"

    public var badgeLabel: String {
        switch self {
        case .builtInRetina: return "RETINA"
        case .zebronicsExternal: return "ZEBRONICS 100Hz"
        case .sidecarIPad: return "IPAD PRO"
        case .genericExternal: return "EXTERNAL"
        }
    }
}

public struct DisplayModeInfo: Identifiable, Hashable {
    public var id: String {
        "\(width)x\(height)@\(String(format: "%.1f", refreshRate))-\(pixelWidth)x\(pixelHeight)"
    }
    public let width: Int
    public let height: Int
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let refreshRate: Double
    public let isHiDPI: Bool
    public let isCurrent: Bool
    public let modeRef: CGDisplayMode

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: DisplayModeInfo, rhs: DisplayModeInfo) -> Bool {
        lhs.id == rhs.id
    }
}

public struct ColorProfileInfo: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let url: URL
    public let isFactory: Bool
    public let isCurrent: Bool

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: ColorProfileInfo, rhs: ColorProfileInfo) -> Bool {
        lhs.id == rhs.id
    }
}

public struct DisplayInfo: Identifiable, Hashable {
    public let id: CGDirectDisplayID
    public let uuid: String
    public let systemName: String
    public var customAlias: String
    public let recognizedType: RecognizedDisplayType
    public let isBuiltIn: Bool
    public let isMain: Bool
    public var bounds: CGRect
    public let pointWidth: Int
    public let pointHeight: Int
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let currentRefreshRate: Double
    public let currentColorProfileName: String
    public let currentColorProfileURL: URL?
    public let isSidecarOrAirPlay: Bool
    public let connectionBus: String
    public let hardwareSpecs: HardwareSpecs
    public let modes: [DisplayModeInfo]
    public let colorProfiles: [ColorProfileInfo]

    public var displayName: String {
        if !customAlias.isEmpty {
            return customAlias
        }
        return systemName
    }

    public var aspectRatio: CGFloat {
        guard pointHeight > 0 else { return 16.0 / 9.0 }
        return CGFloat(pointWidth) / CGFloat(pointHeight)
    }

    public var hardwareCategory: String {
        return hardwareSpecs.generation
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(bounds.origin.x)
        hasher.combine(bounds.origin.y)
    }

    public static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.bounds == rhs.bounds &&
        lhs.currentRefreshRate == rhs.currentRefreshRate &&
        lhs.currentColorProfileName == rhs.currentColorProfileName &&
        lhs.customAlias == rhs.customAlias
    }
}
