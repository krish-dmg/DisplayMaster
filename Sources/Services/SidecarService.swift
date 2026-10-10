import Foundation
import AppKit
import ObjectiveC
import Combine

public struct SidecarDeviceItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let model: String
    public let isConnected: Bool
    public let rawDevice: AnyObject

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: SidecarDeviceItem, rhs: SidecarDeviceItem) -> Bool {
        lhs.id == rhs.id && lhs.isConnected == rhs.isConnected
    }
}

@MainActor
public final class SidecarService: ObservableObject {
    public static let shared = SidecarService()

    @Published public private(set) var availableDevices: [SidecarDeviceItem] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public var statusMessage: String?
    @Published public var errorMessage: String?

    private var sidecarManager: AnyObject?
    private var isSupported: Bool = false

    private init() {
        setupSidecarCore()
    }

    private func setupSidecarCore() {
        guard let bundle = Bundle(path: "/System/Library/PrivateFrameworks/SidecarCore.framework") else {
            return
        }
        bundle.load()

        guard let cls = NSClassFromString("SidecarDisplayManager") as? NSObject.Type else {
            return
        }

        if let supportedVal = cls.perform(NSSelectorFromString("isSupported")) {
            isSupported = (Int(bitPattern: supportedVal.toOpaque()) != 0)
        } else {
            isSupported = true
        }

        if let mgr = cls.perform(NSSelectorFromString("sharedManager"))?.takeUnretainedValue() {
            self.sidecarManager = mgr
            scanDevices()
        }
    }

    public func scanDevices() {
        guard let mgr = sidecarManager else {
            availableDevices = []
            return
        }

        isScanning = true
        defer { isScanning = false }

        var items: [SidecarDeviceItem] = []

        // Query connected devices safely
        var connectedIDs = Set<String>()
        if let connected = mgr.perform(NSSelectorFromString("connectedDevices"))?.takeUnretainedValue() as? [NSObject] {
            for dev in connected {
                let devID = dev.value(forKey: "identifier") as? String ?? UUID().uuidString
                connectedIDs.insert(devID)
            }
        }

        // Query all discoverable devices safely
        if let devices = mgr.perform(NSSelectorFromString("devices"))?.takeUnretainedValue() as? [NSObject] {
            for dev in devices {
                let name = dev.value(forKey: "name") as? String ?? "iPad"
                let model = dev.value(forKey: "model") as? String ?? "iPad Pro"
                let devID = dev.value(forKey: "identifier") as? String ?? UUID().uuidString
                let isConn = connectedIDs.contains(devID)

                items.append(
                    SidecarDeviceItem(
                        id: devID,
                        name: name,
                        model: model,
                        isConnected: isConn,
                        rawDevice: dev
                    )
                )
            }
        }

        self.availableDevices = items
    }

    public func connect(device: SidecarDeviceItem, completion: @escaping (Bool) -> Void) {
        guard let mgr = sidecarManager else {
            errorMessage = "Sidecar service is unavailable. Opening macOS Displays settings..."
            openSystemAddDisplaySettings()
            completion(false)
            return
        }

        statusMessage = "Initiating connection to \(device.name)..."

        let selector = NSSelectorFromString("connectToDevice:completion:")
        guard mgr.responds(to: selector) else {
            openSystemAddDisplaySettings()
            completion(true)
            return
        }

        typealias ConnectFunc = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Void
        let methodIMP = mgr.method(for: selector)
        let fn = unsafeBitCast(methodIMP, to: ConnectFunc.self)

        // Heap-allocated malloc block cast to AnyObject to prevent non-escaping closure trapping
        let completionBlock: @convention(block) (NSError?) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                if let err = error {
                    self?.errorMessage = "Sidecar connection note: \(err.localizedDescription)"
                    self?.openSystemAddDisplaySettings()
                    completion(false)
                } else {
                    self?.statusMessage = "Successfully connected to \(device.name)!"
                    self?.scanDevices()
                    completion(true)
                }
            }
        }

        let blockObject = unsafeBitCast(completionBlock, to: AnyObject.self)
        fn(mgr, selector, device.rawDevice, blockObject)
    }

    public func disconnect(device: SidecarDeviceItem, completion: @escaping (Bool) -> Void) {
        guard let mgr = sidecarManager else {
            completion(false)
            return
        }

        let selector = NSSelectorFromString("disconnectFromDevice:completion:")
        guard mgr.responds(to: selector) else {
            completion(false)
            return
        }

        typealias DisconnectFunc = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Void
        let methodIMP = mgr.method(for: selector)
        let fn = unsafeBitCast(methodIMP, to: DisconnectFunc.self)

        let completionBlock: @convention(block) (NSError?) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                if let err = error {
                    self?.errorMessage = "Disconnect error: \(err.localizedDescription)"
                    completion(false)
                } else {
                    self?.statusMessage = "Disconnected from \(device.name)."
                    self?.scanDevices()
                    completion(true)
                }
            }
        }

        let blockObject = unsafeBitCast(completionBlock, to: AnyObject.self)
        fn(mgr, selector, device.rawDevice, blockObject)
    }

    public func openSystemAddDisplaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openScreenMirroring() {
        let scriptSource = """
        tell application "System Events"
            tell process "ControlCenter"
                try
                    click menu bar item "Control Center" of menu bar 1
                end try
            end tell
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            script.executeAndReturnError(&errorInfo)
        }
    }
}
