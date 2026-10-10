import SwiftUI
import CoreGraphics
import AppKit

public struct DisplayInspectorView: View {
    @ObservedObject var manager: DisplayManager
    let display: DisplayInfo

    @State private var aliasInput: String = ""
    @State private var selectedResolution: String = ""
    @State private var selectedRefreshRate: Double = 60.0
    @State private var selectedProfileID: String = ""
    @State private var isProcessing: Bool = false

    public init(manager: DisplayManager, display: DisplayInfo) {
        self.manager = manager
        self.display = display
    }

    private var uniqueResolutions: [(width: Int, height: Int, isHiDPI: Bool)] {
        var seen = Set<String>()
        var list: [(width: Int, height: Int, isHiDPI: Bool)] = []
        for m in display.modes {
            let key = "\(m.width)x\(m.height)"
            if !seen.contains(key) {
                seen.insert(key)
                list.append((m.width, m.height, m.isHiDPI))
            }
        }
        return list
    }

    private var supportedRefreshRatesForSelectedResolution: [Double] {
        guard let parsed = parseResolution(selectedResolution) else {
            return [display.currentRefreshRate]
        }
        let rates = display.modes
            .filter { $0.width == parsed.width && $0.height == parsed.height }
            .map { $0.refreshRate }
        let uniqueRates = Array(Set(rates)).sorted()
        return uniqueRates.isEmpty ? [60.0] : uniqueRates
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Monitor Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(display.displayName)
                                    .font(.title)
                                    .fontWeight(.bold)

                                Text(display.recognizedType.badgeLabel)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .cornerRadius(4)

                                if display.isMain {
                                    Text("MAIN")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }

                            Text(display.hardwareCategory)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Live Signal: \(display.pointWidth)x\(display.pointHeight) @ \(String(format: "%.0f", display.currentRefreshRate))Hz | Connection: \(display.connectionBus)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Button {
                            manager.identifyDisplay(displayID: display.id)
                        } label: {
                            Label("Identify Screen", systemImage: "macwindow.badge.plus")
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    // Recognition Custom Alias Editor
                    HStack(spacing: 10) {
                        Text("Custom Display Name:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        TextField("Set custom display name...", text: $aliasInput)
                            .textFieldStyle(.roundedBorder)

                        Button("Save Name") {
                            manager.updateDisplayAlias(displayID: display.id, newAlias: aliasInput)
                        }
                        .buttonStyle(.bordered)
                        .disabled(aliasInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // Deep Device Identifier & Hardware Specifications Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Deep Hardware Identification", systemImage: "info.circle.fill")
                            .font(.headline)
                        Spacer()
                        Text("Model: \(display.hardwareSpecs.modelIdentifier)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow {
                            Text("Device Generation:")
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text(display.hardwareSpecs.generation)
                                .fontWeight(.semibold)
                        }

                        GridRow {
                            Text("Processor / Controller:")
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text(display.hardwareSpecs.processorOrChipset)
                        }

                        GridRow {
                            Text("Panel Technology:")
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text(display.hardwareSpecs.panelTechnology)
                        }

                        GridRow {
                            Text("Physical Refresh Cap:")
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text(display.hardwareSpecs.physicalRefreshCapability)
                                .foregroundStyle(display.hardwareSpecs.physicalRefreshCapability.contains("120") ? .blue : .primary)
                        }

                        GridRow {
                            Text("Hardware Bus:")
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text(display.hardwareSpecs.connectionBus)
                        }

                        GridRow {
                            Text("Hardware UUID:")
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text(display.uuid)
                                .font(.system(.caption2, design: .monospaced))
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // Tuning Section 1: Resolution & Refresh Rate
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Resolution & Refresh Rate Tuning", systemImage: "slider.horizontal.3")
                            .font(.headline)
                        Spacer()
                        Text("Active: \(String(format: "%.0f", display.currentRefreshRate)) Hz")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }

                    HStack(spacing: 16) {
                        // Resolution Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Resolution")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Picker("Resolution", selection: $selectedResolution) {
                                ForEach(uniqueResolutions, id: \.width) { res in
                                    let label = "\(res.width) x \(res.height)\(res.isHiDPI ? " (Retina)" : "")"
                                    Text(label).tag("\(res.width)x\(res.height)")
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .onChange(of: selectedResolution) {
                                if let highest = supportedRefreshRatesForSelectedResolution.last {
                                    selectedRefreshRate = highest
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Refresh Rate Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Refresh Rate")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Picker("Refresh Rate", selection: $selectedRefreshRate) {
                                ForEach(supportedRefreshRatesForSelectedResolution, id: \.self) { rate in
                                    Text("\(String(format: "%.0f", rate)) Hertz").tag(rate)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Apply Button
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Action")
                                .font(.subheadline)
                                .foregroundStyle(.clear)

                            Button {
                                applyResolutionAndRefresh()
                            } label: {
                                Label("Apply Mode", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isProcessing)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // Tuning Section 2: ColorSync Native Profiles
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("ColorSync Native Color Profile", systemImage: "paintpalette")
                            .font(.headline)

                        Spacer()

                        Button {
                            revertToFactoryProfile()
                        } label: {
                            Label("Reset to Factory", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }

                    Text("Switch between native macOS color profiles (Display P3, Adobe RGB 1998, sRGB, etc.) directly in ColorSync hardware management.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Color Profile", selection: $selectedProfileID) {
                        ForEach(display.colorProfiles) { profile in
                            HStack {
                                Text(profile.name)
                                if profile.isCurrent {
                                    Text("(Active)")
                                }
                            }
                            .tag(profile.id)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        applyColorProfile()
                    } label: {
                        Label("Apply Color Profile", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing || selectedProfileID.isEmpty)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
        .onAppear {
            syncSelections()
        }
        .onChange(of: display.id) {
            syncSelections()
        }
    }

    private func syncSelections() {
        aliasInput = display.customAlias
        selectedResolution = "\(display.pointWidth)x\(display.pointHeight)"
        selectedRefreshRate = display.currentRefreshRate

        if let currentProf = display.colorProfiles.first(where: { $0.isCurrent }) {
            selectedProfileID = currentProf.id
        } else if let firstProf = display.colorProfiles.first {
            selectedProfileID = firstProf.id
        }
    }

    private func parseResolution(_ str: String) -> (width: Int, height: Int)? {
        let parts = str.split(separator: "x")
        guard parts.count == 2,
              let w = Int(parts[0]),
              let h = Int(parts[1]) else { return nil }
        return (w, h)
    }

    private func applyResolutionAndRefresh() {
        guard let parsed = parseResolution(selectedResolution) else { return }
        isProcessing = true
        defer { isProcessing = false }

        let candidateModes = display.modes.filter {
            $0.width == parsed.width && $0.height == parsed.height
        }

        guard let matchingMode = candidateModes.min(by: {
            abs($0.refreshRate - selectedRefreshRate) < abs($1.refreshRate - selectedRefreshRate)
        }) else {
            manager.errorMessage = "No matching mode found for \(selectedResolution) at \(selectedRefreshRate)Hz"
            return
        }

        do {
            try manager.setDisplayMode(displayID: display.id, mode: matchingMode.modeRef)
        } catch {
            manager.errorMessage = error.localizedDescription
        }
    }

    private func applyColorProfile() {
        guard let profile = display.colorProfiles.first(where: { $0.id == selectedProfileID }) else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            try manager.setColorProfile(displayID: display.id, profileURL: profile.url)
        } catch {
            manager.errorMessage = error.localizedDescription
        }
    }

    private func revertToFactoryProfile() {
        isProcessing = true
        defer { isProcessing = false }

        do {
            try manager.resetColorProfileToFactory(displayID: display.id)
        } catch {
            manager.errorMessage = error.localizedDescription
        }
    }
}
