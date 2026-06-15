//
//  SettingsView.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppState.self) private var appState
    @State private var selection: SettingsSection = .general
    @State private var availableCameras: [AVCaptureDevice] = []

    var body: some View {
        @Bindable var appState = appState

        TabView {
            ForEach(SettingsSection.allCases) { section in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(section.title)
                                .font(.system(size: 24, weight: .bold))

                            Text(section.subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        selectedContent(for: section)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .tabItem {
                    Label(section.title, systemImage: section.symbolName)
                }
                .tag(section)
            }
        }
        .frame(width: 600, height: 460)
    }

    private var selectedMusicProvider: AppState.MusicProvider {
        AppState.MusicProvider(rawValue: appState.selectedMusicProvider) ?? .spotify
    }

    @ViewBuilder
    private func selectedContent(for section: SettingsSection) -> some View {
        @Bindable var appState = appState

        switch section {
        case .general:
            settingsGroup {
                LabeledContent("Version", value: appVersionText)

                Divider()

                Toggle("Open NotchAgent at login", isOn: openAtLoginBinding)
                LabeledContent("Login item", value: appState.startupStatusMessage)

                Picker("Global shortcut", selection: shortcutBinding) {
                    Text("Option + Space").tag("Option + Space")
                    Text("Command + Space").tag("Command + Space")
                    Text("Control + Space").tag("Control + Space")
                }
                LabeledContent("Shortcut action", value: appState.shortcutStatusMessage)

                Divider()

                LabeledContent("Updates", value: appState.updateStatusMessage)

                HStack(spacing: 10) {
                    Button(appState.updateCheckInProgress ? "Checking..." : "Check for Updates") {
                        coordinator.checkForUpdates(force: true)
                    }
                    .disabled(appState.updateCheckInProgress)

                    Button("Open Release") {
                        coordinator.openLatestRelease()
                    }
                    .disabled(appState.updateReleaseURL == nil || !appState.isUpdateAvailable)
                }
            }
        case .notch:
            settingsGroup {
                Picker("Preview state", selection: $appState.notchState) {
                    ForEach(NotchState.allCases) { state in
                        Text(state.rawValue.capitalized).tag(state)
                    }
                }

                Toggle("Close on outside click", isOn: $appState.closeSurfaceOnOutsideClick)
                Button("Collapse notch") {
                    coordinator.notchViewModel.closeSurface()
                }
            }
        case .widgets:
            settingsGroup {
                Toggle("Music", isOn: $appState.showSpotifyStatus)
                if appState.showSpotifyStatus {
                    Picker("Music provider", selection: $appState.selectedMusicProvider) {
                        ForEach(AppState.MusicProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }
                    .onChange(of: appState.selectedMusicProvider) { _, newValue in
                        coordinator.notchViewModel.selectMusicProvider(newValue)
                    }

                    Picker("Compact icon style", selection: $appState.compactMediaIconStyle) {
                        ForEach(AppState.CompactMediaIconStyle.allCases) { style in
                            Text(style.rawValue).tag(style.rawValue)
                        }
                    }
                }
                
                Divider()
                
                Toggle("Mirror / Camera", isOn: $appState.showMirrorWidget)
                if appState.showMirrorWidget {
                    Picker("Camera Source", selection: $appState.selectedCameraID) {
                        Text("Auto (System Default)").tag("")
                        ForEach(availableCameras, id: \.uniqueID) { camera in
                            Text(camera.localizedName).tag(camera.uniqueID)
                        }
                    }
                }
                
                Divider()
                
                Toggle("Calendar", isOn: $appState.showCalendarWidget)
                if appState.showCalendarWidget {
                    Toggle("Sync Apple Calendar", isOn: $appState.syncAppleCalendar)
                        .onChange(of: appState.syncAppleCalendar) { _, newValue in
                            if newValue {
                                coordinator.notchViewModel.fetchNextCalendarEvent()
                            }
                        }
                }
                
                Divider()
                
                Toggle("Weather", isOn: $appState.showWeatherWidget)
                if appState.showWeatherWidget {
                    TextField("Location (e.g. Istanbul)", text: $appState.weatherLocation)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .onAppear {
                let session = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera, .external],
                    mediaType: .video,
                    position: .unspecified
                )
                availableCameras = session.devices
            }
        case .surfaces:
            settingsGroup {
                Picker("Accent source", selection: $appState.accentBehavior) {
                    Text("Album art").tag("Album art")
                    Text("Agent state").tag("Agent state")
                    Text("Static black").tag("Static black")
                }

                Divider()

                LabeledContent("\(selectedMusicProvider.rawValue) surface", value: appState.showSpotifyStatus ? appState.spotifyStatusMessage : "Hidden")
                LabeledContent("Mirror surface", value: appState.showMirrorWidget ? "Enabled" : "Hidden")
                LabeledContent("Calendar surface", value: appState.showCalendarWidget ? "Enabled" : "Hidden")
                LabeledContent("Weather surface", value: appState.showWeatherWidget ? "Enabled" : "Hidden")

                HStack(spacing: 10) {
                    Button("Refresh \(selectedMusicProvider.rawValue)") {
                        coordinator.notchViewModel.refreshSpotifyState()
                    }
                    .disabled(!appState.showSpotifyStatus)

                    Button("Open \(selectedMusicProvider.rawValue)") {
                        coordinator.notchViewModel.toggleSurface(.spotify)
                    }
                    .disabled(!appState.showSpotifyStatus)

                    Button("Open Mirror") {
                        coordinator.notchViewModel.toggleSurface(.mirror)
                    }
                    .disabled(!appState.showMirrorWidget)
                }
            }
        case .ai:
            settingsGroup {
                Picker("Router mode", selection: $appState.routerModel) {
                    Text("Rules first").tag("Rules first")
                    Text("Ollama fallback").tag("Ollama fallback")
                    Text("Manual only").tag("Manual only")
                }

                LabeledContent("Router model", value: "qwen2.5:3b")
                LabeledContent("Main model", value: "qwen2.5:7b")
                LabeledContent("Agent state", value: appState.notchState.title)
                LabeledContent("Last message", value: appState.agentStatusMessage)

                HStack(spacing: 10) {
                    Button("Run demo") {
                        coordinator.notchViewModel.runDemoFlow()
                    }

                    Button("Reset agent") {
                        coordinator.notchViewModel.resetAgent()
                    }
                }
            }
        case .privacy:
            settingsGroup {
                LabeledContent("Microphone", value: appState.notchState == .listening ? "Listening" : "Used by agent listening")
                LabeledContent("Camera", value: appState.showMirrorWidget ? "Mirror enabled" : "Mirror hidden")
                LabeledContent("Automation", value: "Required for music controls")
            }
        }
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .background(
            .quaternary.opacity(0.32),
            in: RoundedRectangle(cornerRadius: Design.Radii.settingsGroup, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Design.Radii.settingsGroup, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.openAtLogin },
            set: { coordinator.setOpenAtLogin($0) }
        )
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private var shortcutBinding: Binding<String> {
        Binding(
            get: { appState.defaultShortcut },
            set: { coordinator.setDefaultShortcut($0) }
        )
    }
}

// MARK: - Sections

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case notch
    case widgets
    case surfaces
    case ai
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .notch: "Notch"
        case .widgets: "Widgets"
        case .surfaces: "Surfaces"
        case .ai: "AI"
        case .privacy: "Privacy"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Startup, visibility, and shortcut behavior."
        case .notch: "Compact status and top-center notch behavior."
        case .widgets: "Toggle notch widgets: media, mirror, calendar, weather."
        case .surfaces: "Accent and expanded surface presentation."
        case .ai: "Intent routing defaults for future model integration."
        case .privacy: "Permission status for local capabilities."
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .notch: "capsule.tophalf.filled"
        case .widgets: "square.grid.2x2"
        case .surfaces: "rectangle.3.group"
        case .ai: "brain.head.profile"
        case .privacy: "lock.shield"
        }
    }
}
