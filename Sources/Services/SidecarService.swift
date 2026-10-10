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

        // Query connected devices
        var connectedIDs = Set<String>()
        if let connected = mgr.perform(NSSelectorFromString("connectedDevices"))?.takeUnretainedValue() as? [NSObject] {
            for dev in connected {
                let devID = dev.value(forKey: "identifier") as? String ?? UUID().uuidString
                connectedIDs.insert(devID)
            }
        }

        // Query all discoverable devices
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
            errorMessage = "Sidecar service is not initialized."
            completion(false)
            return
        }

        statusMessage = "Connecting to \(device.name)..."

        // Perform connectToDevice:completion:
        // Because completion takes a block, we invoke via performSelector or open macOS Displays Settings
        let selector = NSSelectorFromString("connectToDevice:completion:")
        if mgr.responds(to: selector) {
            typealias ConnectFunc = @convention(c) (AnyObject, Selector, AnyObject, @convention(block) (NSError?) -> Void) -> Void
            let methodIMP = mgr.method(for: selector)
            let fn = unsafeBitCast(methodIMP, to: ConnectFunc.self)

            fn(mgr, selector, device.rawDevice) { [weak self] error in
                DispatchQueue.main.async {
                    if let err = error {
                        self?.errorMessage = "Failed to connect: \(err.localizedDescription)"
                        completion(false)
                    } else {
                        self?.statusMessage = "Connected to \(device.name) successfully!"
                        self?.scanDevices()
                        completion(true)
                    }
                }
            }
        } else {
            openSystemAddDisplaySettings()
            completion(true)
        }
    }

    public func disconnect(device: SidecarDeviceItem, completion: @escaping (Bool) -> Void) {
        guard let mgr = sidecarManager else {
            completion(false)
            return
        }

        let selector = NSSelectorFromString("disconnectFromDevice:completion:")
        if mgr.responds(to: selector) {
            typealias DisconnectFunc = @convention(c) (AnyObject, Selector, AnyObject, @convention(block) (NSError?) -> Void) -> Void
            let methodIMP = mgr.method(for: selector)
            let fn = unsafeBitCast(methodIMP, to: DisconnectFunc.self)

            fn(mgr, selector, device.rawDevice) { [weak self] error in
                DispatchQueue.main.async {
                    if let err = error {
                        self?.errorMessage = "Failed to disconnect: \(err.localizedDescription)"
                        completion(false)
                    } else {
                        self?.statusMessage = "Disconnected from \(device.name)."
                        self?.scanDevices()
                        completion(true)
                    }
                }
            }
        } else {
            completion(false)
        }
    }

    public func openSystemAddDisplaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openScreenMirroring() {
        // Run native AppleScript to trigger Screen Mirroring in Control Center
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
