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
    @Published public var statusMessage: String?
    @Published public var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    public init() {
        loadAvailableColorProfiles()
        refreshDisplays()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshDisplays()
            }
            .store(in: &cancellables)
    }

    public func loadAvailableColorProfiles() {
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

        // Sort so common standards appear near the top
        self.availableColorProfiles = profiles.sorted { a, b in
            let priorityNames = ["Display P3", "Adobe RGB (1998)", "sRGB", "Rec. ITU-R BT.709", "Rec. ITU-R BT.2020", "Color LCD"]
            let aPriority = priorityNames.firstIndex(where: { a.name.contains($0) }) ?? 999
            let bPriority = priorityNames.firstIndex(where: { b.name.contains($0) }) ?? 999
            if aPriority != bPriority {
                return aPriority < bPriority
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
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

        var newDisplays: [DisplayInfo] = []

        for displayID in activeDisplayIDs {
            let bounds = CGDisplayBounds(displayID)
            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            let isMain = CGDisplayIsMain(displayID) != 0

            // Locate corresponding NSScreen for human localizedName and color space
            let matchingScreen = NSScreen.screens.first { screen in
                let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                return id == displayID
            }

            var screenName = matchingScreen?.localizedName ?? "Display \(displayID)"
            let isSidecarOrAirPlay = screenName.localizedCaseInsensitiveContains("iPad") ||
                                    screenName.localizedCaseInsensitiveContains("AirPlay") ||
                                    screenName.localizedCaseInsensitiveContains("Sidecar")

            if screenName.isEmpty {
                screenName = isBuiltIn ? "Built-in Retina Display" : "External Display"
            }

            // Display UUID
            var uuidString = "Unknown-UUID"
            var cfUUID: CFUUID? = nil
            if let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID) {
                let retainedUUID = uuidRef.takeRetainedValue()
                cfUUID = retainedUUID
                uuidString = CFUUIDCreateString(nil, retainedUUID) as String
            }

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

            // Current Mode
            let currentMode = CGDisplayCopyDisplayMode(displayID)
            let pointW = currentMode?.width ?? Int(bounds.width)
            let pointH = currentMode?.height ?? Int(bounds.height)
            let pixelW = currentMode?.pixelWidth ?? pointW
            let pixelH = currentMode?.pixelHeight ?? pointH
            let refreshRate = currentMode?.refreshRate ?? 60.0

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

            // Sort modes by descending resolution, then refresh rate
            modesList.sort { a, b in
                if a.width != b.width { return a.width > b.width }
                if a.height != b.height { return a.height > b.height }
                return a.refreshRate > b.refreshRate
            }

            // Map color profiles with current selection tagged
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
                    name: screenName,
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
            defaultProfileKey: kCFNull!
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
        let name = displays.first(where: { $0.id == displayID })?.name ?? "Display \(displayID)"
        ScreenIdentifierOverlay.shared.flash(displayID: displayID, displayName: name)
    }
}
