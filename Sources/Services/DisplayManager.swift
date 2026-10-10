import Foundation
import CoreGraphics
import ColorSync
import AppKit
import Combine

@MainActor
public final class DisplayManager: ObservableObject {
    public static let shared = DisplayManager()

    @Published public private(set) var displays: [DisplayInfo] = []
    @Published public var selectedDisplayID: CGDirectDisplayID?
    @Published public private(set) var availableColorProfiles: [ColorProfileInfo] = []
    @Published public var showAddDisplaySheet: Bool = false
    @Published public var statusMessage: String?
    @Published public var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let userDefaultsAliasesKey = "DisplayMaster_DisplayAliases"

    public init() {
        refreshDisplays()
        loadAvailableColorProfilesAsync()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshDisplays()
            }
            .store(in: &cancellables)
    }

    private func getSavedAliases() -> [String: String] {
        return UserDefaults.standard.dictionary(forKey: userDefaultsAliasesKey) as? [String: String] ?? [:]
    }

    public func updateDisplayAlias(displayID: CGDirectDisplayID, newAlias: String) {
        guard let display = displays.first(where: { $0.id == displayID }) else { return }
        var aliases = getSavedAliases()
        aliases[display.uuid] = newAlias
        UserDefaults.standard.set(aliases, forKey: userDefaultsAliasesKey)
        refreshDisplays()
        statusMessage = "Updated display name to '\(newAlias)'"
    }

    private func getHostMacModel() -> String {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func resolveDeepHardwareSpecs(
        isBuiltIn: Bool,
        isSidecar: Bool,
        rawName: String,
        refreshRate: Double,
        pointW: Int,
        pointH: Int,
        pixelW: Int,
        pixelH: Int
    ) -> (RecognizedDisplayType, String, HardwareSpecs) {
        if isBuiltIn {
            let hostModel = getHostMacModel()
            let gen: String
            let chip: String
            let panel: String

            if hostModel.contains("MacBookAir10,1") {
                gen = "MacBook Air 13-inch (M1, 2020)"
                chip = "Apple M1 (8-Core CPU, 7-Core GPU, 16-Core Neural Engine)"
                panel = "13.3-inch Retina LCD (2560 x 1600 native, 227 ppi, P3 Color, 400 nits)"
            } else if hostModel.contains("Mac14,2") {
                gen = "MacBook Air 13-inch (M2, 2022)"
                chip = "Apple M2 (8-Core CPU, 8/10-Core GPU)"
                panel = "13.6-inch Liquid Retina Display (2560 x 1664 native, 500 nits)"
            } else if hostModel.contains("Mac14,15") {
                gen = "MacBook Air 15-inch (M2, 2023)"
                chip = "Apple M2 (8-Core CPU, 10-Core GPU)"
                panel = "15.3-inch Liquid Retina Display (2880 x 1864 native, 500 nits)"
            } else if hostModel.contains("Mac15,") {
                gen = "MacBook Air (M3, 2024)"
                chip = "Apple M3 (8-Core CPU, 10-Core GPU)"
                panel = "Liquid Retina Display with Dual-External Clamshell Support"
            } else {
                gen = "Apple Silicon MacBook Retina Display"
                chip = "Apple Silicon SoC"
                panel = "Retina LCD Display Panel"
            }

            let specs = HardwareSpecs(
                modelIdentifier: hostModel,
                generation: gen,
                processorOrChipset: chip,
                panelTechnology: panel,
                physicalRefreshCapability: "60.00 Hz (Fixed Hardware Retina)",
                connectionBus: "Internal Embedded DisplayPort (eDP)"
            )
            return (.builtInRetina, "Built-in Liquid Retina", specs)
        } else if isSidecar {
            // Check connected sidecar devices
            let sidecarDevices = SidecarService.shared.availableDevices
            let sidecarModelCode = sidecarDevices.first?.model ?? "iPad8,3"

            let gen: String
            let chip: String
            let panel: String

            if sidecarModelCode.contains("iPad8,1") || sidecarModelCode.contains("iPad8,2") ||
               sidecarModelCode.contains("iPad8,3") || sidecarModelCode.contains("iPad8,4") {
                gen = "iPad Pro 11-inch (1st Gen, 2018)"
                chip = "Apple A12X Bionic (8-Core CPU, 7-Core GPU)"
                panel = "11-inch Liquid Retina IPS (2388 x 1668 at 264 ppi, P3 Wide Color, True Tone)"
            } else if sidecarModelCode.contains("iPad8,5") || sidecarModelCode.contains("iPad8,6") ||
                      sidecarModelCode.contains("iPad8,7") || sidecarModelCode.contains("iPad8,8") {
                gen = "iPad Pro 12.9-inch (3rd Gen, 2018)"
                chip = "Apple A12X Bionic (8-Core CPU, 7-Core GPU)"
                panel = "12.9-inch Liquid Retina IPS (2732 x 2048 at 264 ppi, P3 Color)"
            } else if sidecarModelCode.contains("iPad13,") {
                gen = "iPad Pro (M1, 3rd/5th Gen, 2021)"
                chip = "Apple M1 (8-Core CPU, 8-Core GPU)"
                panel = "Liquid Retina / XDR Mini-LED (120Hz ProMotion)"
            } else if sidecarModelCode.contains("iPad14,") {
                gen = "iPad Pro (M2, 4th/6th Gen, 2022)"
                chip = "Apple M2 (8-Core CPU, 10-Core GPU)"
                panel = "Liquid Retina / XDR Mini-LED (120Hz ProMotion)"
            } else if sidecarModelCode.contains("iPad16,") {
                gen = "iPad Pro (M4, 2024)"
                chip = "Apple M4 (Tandem OLED)"
                panel = "Ultra Retina Tandem OLED (120Hz ProMotion)"
            } else {
                gen = "iPad Pro 11-inch (1st Gen, 2018)"
                chip = "Apple A12X Bionic"
                panel = "Liquid Retina Display (120Hz ProMotion Panel)"
            }

            let specs = HardwareSpecs(
                modelIdentifier: sidecarModelCode,
                generation: gen,
                processorOrChipset: chip,
                panelTechnology: panel,
                physicalRefreshCapability: "120.00 Hz ProMotion Physical Panel (Streamed at 60Hz via Sidecar)",
                connectionBus: "High-Speed USB-C Cable / Peer-to-Peer AWDL Wireless"
            )
            return (.sidecarIPad, "iPad Pro (Sidecar)", specs)
        } else {
            // External monitor
            let isZeb = rawName.localizedCaseInsensitiveContains("HDMI") || refreshRate >= 99.0
            let gen = isZeb ? "Zebronics 22-inch Full HD Monitor" : "External Desktop Monitor"
            let sysName = isZeb ? "Zebronics Monitor (HDMI)" : (rawName.isEmpty ? "External Monitor" : rawName)
            let chip = "HDMI 2.0 / DisplayPort Alt-Mode Controller"
            let panel = "\(pointW) x \(pointH) Full High Definition (16:9 Widescreen)"
            let refreshStr = "\(String(format: "%.0f", refreshRate)) Hz High-Refresh Hardware"

            let specs = HardwareSpecs(
                modelIdentifier: isZeb ? "Zebronics-HDMI-100Hz" : "External-DisplayPort-HDMI",
                generation: gen,
                processorOrChipset: chip,
                panelTechnology: panel,
                physicalRefreshCapability: refreshStr,
                connectionBus: "HDMI 2.0 via USB-C DisplayPort Alt Mode"
            )
            return (isZeb ? .zebronicsExternal : .genericExternal, sysName, specs)
        }
    }

    public func loadAvailableColorProfilesAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var profiles: [ColorProfileInfo] = []
            let searchDirectories = [
                URL(fileURLWithPath: "/System/Library/ColorSync/Profiles"),
                URL(fileURLWithPath: "/Library/ColorSync/Profiles"),
                URL(fileURLWithPath: "/Library/ColorSync/Profiles/Displays"),
                URL(fileURLWithPath: "/System/Library/CoreServices/Resources/Profiles")
            ]

            var seenPaths = Set<String>()

            for directory in searchDirectories {
                guard let fileURLs = try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for url in fileURLs {
                    let ext = url.pathExtension.lowercased()
                    guard ext == "icc" || ext == "icm" else { continue }
                    guard !seenPaths.contains(url.path) else { continue }
                    seenPaths.insert(url.path)

                    var displayName = url.deletingPathExtension().lastPathComponent
                    if let unmanaged = ColorSyncProfileCreateWithURL(url as CFURL, nil) {
                        let profile = unmanaged.takeRetainedValue()
                        if let unmanagedDesc = ColorSyncProfileCopyDescriptionString(profile) {
                            let desc = unmanagedDesc.takeRetainedValue() as String
                            if !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                displayName = desc
                            }
                        }
                    }

                    profiles.append(
                        ColorProfileInfo(
                            id: url.path,
                            name: displayName,
                            url: url,
                            isFactory: url.path.contains("/Displays/"),
                            isCurrent: false
                        )
                    )
                }
            }

            let sorted = profiles.sorted { a, b in
                let priorityNames = ["Display P3", "Adobe RGB (1998)", "sRGB", "Rec. ITU-R BT.709", "Rec. ITU-R BT.2020", "Color LCD"]
                let aPriority = priorityNames.firstIndex(where: { a.name.contains($0) }) ?? 999
                let bPriority = priorityNames.firstIndex(where: { b.name.contains($0) }) ?? 999
                if aPriority != bPriority {
                    return aPriority < bPriority
                }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }

            DispatchQueue.main.async {
                self?.availableColorProfiles = sorted
                self?.refreshDisplays()
            }
        }
    }

    public func refreshDisplays() {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else {
            self.displays = []
            return
        }

        var activeDisplayIDs = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &activeDisplayIDs, &count)

        let savedAliases = getSavedAliases()
        var newDisplays: [DisplayInfo] = []

        for displayID in activeDisplayIDs {
            let bounds = CGDisplayBounds(displayID)
            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            let isMain = CGDisplayIsMain(displayID) != 0

            let matchingScreen = NSScreen.screens.first { screen in
                let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                return id == displayID
            }

            let rawScreenName = matchingScreen?.localizedName ?? "Display \(displayID)"
            let isSidecarOrAirPlay = rawScreenName.localizedCaseInsensitiveContains("iPad") ||
                                    rawScreenName.localizedCaseInsensitiveContains("AirPlay") ||
                                    rawScreenName.localizedCaseInsensitiveContains("Sidecar")

            // Display UUID
            var uuidString = "Unknown-UUID"
            var cfUUID: CFUUID? = nil
            if let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID) {
                let retainedUUID = uuidRef.takeRetainedValue()
                cfUUID = retainedUUID
                uuidString = CFUUIDCreateString(nil, retainedUUID) as String
            }

            // Current Mode and Refresh Rate
            let currentMode = CGDisplayCopyDisplayMode(displayID)
            let pointW = currentMode?.width ?? Int(bounds.width)
            let pointH = currentMode?.height ?? Int(bounds.height)
            let pixelW = currentMode?.pixelWidth ?? pointW
            let pixelH = currentMode?.pixelHeight ?? pointH
            let refreshRate = currentMode?.refreshRate ?? 60.0

            // Deep Hardware Specifications Resolution
            let (recognizedType, systemName, hardwareSpecs) = resolveDeepHardwareSpecs(
                isBuiltIn: isBuiltIn,
                isSidecar: isSidecarOrAirPlay,
                rawName: rawScreenName,
                refreshRate: refreshRate,
                pointW: pointW,
                pointH: pointH,
                pixelW: pixelW,
                pixelH: pixelH
            )

            let customAlias = savedAliases[uuidString] ?? ""

            // Color Profile determination
            var currentProfileName = matchingScreen?.colorSpace?.localizedName ?? "System Default"
            var currentProfileURL: URL? = nil

            let deviceClass = kColorSyncDisplayDeviceClass.takeUnretainedValue()
            if let targetUUID = cfUUID,
               let infoRef = ColorSyncDeviceCopyDeviceInfo(deviceClass, targetUUID) {
                let infoDict = infoRef.takeRetainedValue() as NSDictionary
                let customProfilesKey = kColorSyncCustomProfiles.takeUnretainedValue() as String
                if let customProfiles = infoDict[customProfilesKey] as? [String: Any],
                   let profileVal = customProfiles.values.first {
                    if let urlStr = profileVal as? String, let parsedURL = URL(string: urlStr) {
                        currentProfileURL = parsedURL
                        let matching = availableColorProfiles.first { $0.url.path == parsedURL.path }
                        currentProfileName = matching?.name ?? parsedURL.deletingPathExtension().lastPathComponent
                    } else if let parsedURL = profileVal as? URL {
                        currentProfileURL = parsedURL
                        let matching = availableColorProfiles.first { $0.url.path == parsedURL.path }
                        currentProfileName = matching?.name ?? parsedURL.deletingPathExtension().lastPathComponent
                    }
                }
            }

            // Available Modes
            let options = [kCGDisplayShowDuplicateLowResolutionModes as String: kCFBooleanTrue] as CFDictionary
            var modesList: [DisplayModeInfo] = []
            if let allModes = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode] {
                var seenKeys = Set<String>()
                for mode in allModes {
                    guard mode.isUsableForDesktopGUI() else { continue }
                    let w = mode.width
                    let h = mode.height
                    let pw = mode.pixelWidth
                    let ph = mode.pixelHeight
                    let rate = mode.refreshRate
                    let isHiDPI = pw > w || ph > h
                    let isCurrent = (w == pointW && h == pointH && abs(rate - refreshRate) < 0.1)

                    let key = "\(w)x\(h)@\(String(format: "%.1f", rate))-\(pw)x\(ph)"
                    if !seenKeys.contains(key) {
                        seenKeys.insert(key)
                        modesList.append(
                            DisplayModeInfo(
                                width: w,
                                height: h,
                                pixelWidth: pw,
                                pixelHeight: ph,
                                refreshRate: rate,
                                isHiDPI: isHiDPI,
                                isCurrent: isCurrent,
                                modeRef: mode
                            )
                        )
                    }
                }
            }

            modesList.sort { a, b in
                if a.width != b.width { return a.width > b.width }
                if a.height != b.height { return a.height > b.height }
                return a.refreshRate > b.refreshRate
            }

            let profilesWithCurrent = availableColorProfiles.map { item in
                ColorProfileInfo(
                    id: item.id,
                    name: item.name,
                    url: item.url,
                    isFactory: item.isFactory,
                    isCurrent: item.name == currentProfileName || item.url.path == currentProfileURL?.path
                )
            }

            newDisplays.append(
                DisplayInfo(
                    id: displayID,
                    uuid: uuidString,
                    systemName: systemName,
                    customAlias: customAlias,
                    recognizedType: recognizedType,
                    isBuiltIn: isBuiltIn,
                    isMain: isMain,
                    bounds: bounds,
                    pointWidth: pointW,
                    pointHeight: pointH,
                    pixelWidth: pixelW,
                    pixelHeight: pixelH,
                    currentRefreshRate: refreshRate,
                    currentColorProfileName: currentProfileName,
                    currentColorProfileURL: currentProfileURL,
                    isSidecarOrAirPlay: isSidecarOrAirPlay,
                    connectionBus: hardwareSpecs.connectionBus,
                    hardwareSpecs: hardwareSpecs,
                    modes: modesList,
                    colorProfiles: profilesWithCurrent
                )
            )
        }

        self.displays = newDisplays
        if selectedDisplayID == nil || !newDisplays.contains(where: { $0.id == selectedDisplayID }) {
            selectedDisplayID = newDisplays.first?.id
        }
    }

    public func applyArrangement(origins: [CGDirectDisplayID: CGPoint]) throws {
        var configRef: CGDisplayConfigRef?
        let beginStatus = CGBeginDisplayConfiguration(&configRef)
        guard beginStatus == .success, let config = configRef else {
            throw NSError(domain: "DisplayMaster", code: Int(beginStatus.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to initiate display configuration transaction (\(beginStatus))"
            ])
        }

        for (displayID, origin) in origins {
            let xPos = Int32(round(origin.x))
            let yPos = Int32(round(origin.y))
            let confStatus = CGConfigureDisplayOrigin(config, displayID, xPos, yPos)
            if confStatus != .success {
                CGCancelDisplayConfiguration(config)
                throw NSError(domain: "DisplayMaster", code: Int(confStatus.rawValue), userInfo: [
                    NSLocalizedDescriptionKey: "Failed to configure origin for display \(displayID)"
                ])
            }
        }

        let completeStatus = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeStatus == .success else {
            throw NSError(domain: "DisplayMaster", code: Int(completeStatus.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to commit display layout configuration (\(completeStatus))"
            ])
        }

        refreshDisplays()
        statusMessage = "Display layout successfully applied!"
    }

    public func setDisplayMode(displayID: CGDirectDisplayID, mode: CGDisplayMode) throws {
        var configRef: CGDisplayConfigRef?
        let beginStatus = CGBeginDisplayConfiguration(&configRef)
        guard beginStatus == .success, let config = configRef else {
            throw NSError(domain: "DisplayMaster", code: Int(beginStatus.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to begin display configuration"
            ])
        }

        let configStatus = CGConfigureDisplayWithDisplayMode(config, displayID, mode, nil)
        guard configStatus == .success else {
            CGCancelDisplayConfiguration(config)
            throw NSError(domain: "DisplayMaster", code: Int(configStatus.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to set display mode on monitor \(displayID)"
            ])
        }

        let completeStatus = CGCompleteDisplayConfiguration(config, .permanently)
        guard completeStatus == .success else {
            throw NSError(domain: "DisplayMaster", code: Int(completeStatus.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to commit display mode changes"
            ])
        }

        refreshDisplays()
        statusMessage = "Resolution and refresh rate updated!"
    }

    public func setColorProfile(displayID: CGDirectDisplayID, profileURL: URL) throws {
        guard let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            throw NSError(domain: "DisplayMaster", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not retrieve display hardware UUID"
            ])
        }

        let cfUUID = uuidRef.takeRetainedValue()
        let deviceClass = kColorSyncDisplayDeviceClass.takeUnretainedValue()
        let defaultProfileKey = kColorSyncDeviceDefaultProfileID.takeUnretainedValue()

        let profileDict: [CFString: Any] = [
            defaultProfileKey: profileURL as CFURL
        ]

        let success = ColorSyncDeviceSetCustomProfiles(deviceClass, cfUUID, profileDict as CFDictionary)
        guard success else {
            throw NSError(domain: "DisplayMaster", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "ColorSync was unable to apply profile: \(profileURL.lastPathComponent)"
            ])
        }

        refreshDisplays()
        statusMessage = "Color profile updated to \(profileURL.deletingPathExtension().lastPathComponent)!"
    }

    public func resetColorProfileToFactory(displayID: CGDirectDisplayID) throws {
        guard let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            throw NSError(domain: "DisplayMaster", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Could not retrieve display hardware UUID"
            ])
        }

        let cfUUID = uuidRef.takeRetainedValue()
        let deviceClass = kColorSyncDisplayDeviceClass.takeUnretainedValue()
        let defaultProfileKey = kColorSyncDeviceDefaultProfileID.takeUnretainedValue()

        let profileDict: [CFString: Any] = [
            defaultProfileKey: kCFNull as Any
        ]

        let success = ColorSyncDeviceSetCustomProfiles(deviceClass, cfUUID, profileDict as CFDictionary)
        guard success else {
            throw NSError(domain: "DisplayMaster", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "ColorSync was unable to reset to factory profile"
            ])
        }

        refreshDisplays()
        statusMessage = "Restored factory color profile!"
    }

    public func identifyDisplay(displayID: CGDirectDisplayID) {
        let name = displays.first(where: { $0.id == displayID })?.displayName ?? "Display \(displayID)"
        ScreenIdentifierOverlay.shared.flash(displayID: displayID, displayName: name)
    }
}
