//
//  AppCoordinator.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Carbon
import AppKit
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

/// Top-level coordinator — owns AppState, NotchViewModel, AICommandManager, and the window controller.
@MainActor @Observable
final class AppCoordinator {
    let appState: AppState
    let notchViewModel: NotchViewModel
    let aiManager: AICommandManager

    private let notchWindowController: NotchWindowController
    private var shortcutRef: EventHotKeyRef?
    private var shortcutEventHandler: EventHandlerRef?

    init() {
        let appState = AppState()
        let viewModel = NotchViewModel(appState: appState)
        let manager = AICommandManager()

        self.appState = appState
        self.notchViewModel = viewModel
        self.aiManager = manager
        self.notchWindowController = NotchWindowController(
            appState: appState,
            viewModel: viewModel
        )

        // Wire AICommandManager callbacks → AppState
        manager.onPhaseChange = { [weak appState, weak viewModel] phase, message in
            guard let appState, let viewModel else { return }
            appState.agentPhase = phase
            appState.agentStatusMessage = message
            appState.agentError = phase == .error ? message : nil
            appState.cacheEntryCount = manager.cacheEntryCount

            // Map agent phase to notch state for UI
            switch phase {
            case .idle:
                viewModel.resetAgent()
            case .listening:
                viewModel.setAgentState(.listening, message: message)
            case .processing:
                viewModel.setAgentState(.thinking, message: message)
            case .executing:
                viewModel.setAgentState(.action, message: message)
            case .done:
                viewModel.setAgentState(.result, message: message)
            case .error:
                viewModel.setAgentState(.error, message: message)
            }
        }

        manager.onTranscriptUpdate = { [weak appState] transcript in
            appState?.agentTranscript = transcript
        }

        manager.onLevelChange = { [weak appState] level in
            appState?.agentInputLevel = level
        }

        manager.onSilenceDetected = { [weak self] in
            guard let self, self.appState.agentSilenceDetection else { return }
            self.stopAndProcess()
        }

        manager.onCommandReady = { [weak appState, weak self] command, wasCacheHit in
            appState?.agentCacheHit = wasCacheHit
            appState?.agentLastResponse = command.summary ?? "Done"
            
            // Automatically execute the command script
            self?.aiManager.executeCommand(command)

            if command.action == "answer" {
                // For chat/answers, expand the UI to show the full text
                appState?.isSurfaceExpanded = true
            } else {
                // For direct actions, keep it compact and hide the surface after 2.5 seconds
                appState?.isSurfaceExpanded = false
                
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    // If it's still showing the agent surface, close it
                    if self?.appState.activeSurface == .agent {
                        self?.appState.activeSurface = .none
                    }
                }
            }
        }

        manager.onSettingChange = { [weak appState] setting, value in
            if setting == "default_music_app" {
                appState?.selectedMusicProvider = value
            }
        }

        manager.onMusicControl = { [weak viewModel] target in
            guard let viewModel else { return }
            switch target.lowercased() {
            case "play", "pause", "playpause", "toggle":
                viewModel.toggleSpotifyPlayback()
            case "next", "skip":
                viewModel.skipSpotifyForward()
            case "previous", "back":
                viewModel.skipSpotifyBackward()
            case "shuffle":
                viewModel.toggleSpotifyShuffle()
            case "repeat":
                viewModel.toggleSpotifyRepeat()
            default:
                break
            }
        }

        manager.onMusicSearch = { [weak viewModel] query in
            viewModel?.searchAndPlayMusic(query: query)
        }

        // Configure AI providers from saved settings
        manager.configureOllama(
            baseURL: appState.ollamaBaseURL,
            model: appState.ollamaModel
        )
        manager.configureOpenAI(
            apiKey: appState.openAIAPIKey,
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4o-mini"
        )
        configureSpeechRecognition()

        // Wire agent action callbacks to the window controller
        notchWindowController.onAgentListen = { [weak self] in
            self?.activateAgentListening()
        }
        notchWindowController.onAgentStopAndProcess = { [weak self] in
            self?.stopAndProcess()
        }
        notchWindowController.onAgentExecute = { [weak self] in
            self?.executeLastCommand()
        }
        notchWindowController.onAgentReset = { [weak self] in
            self?.resetAgent()
        }
        notchWindowController.rebuildRootView()

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.notchWindowController.show()
        }

        configureGlobalShortcut(appState.defaultShortcut)
        refreshLoginItemStatus()
        checkForUpdatesIfNeeded()

        // Check Ollama health on startup
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.checkOllamaHealth()
        }
    }

    func toggleNotchVisibility() {
        appState.isNotchVisible = true
        notchWindowController.show()
    }

    func setNotchVisibility(_ isVisible: Bool) {
        appState.isNotchVisible = isVisible
        if isVisible {
            notchWindowController.show()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }

    func setOpenAtLogin(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            appState.openAtLogin = isEnabled
            appState.startupStatusMessage = isEnabled ? "Enabled" : "Disabled"
        } catch {
            appState.openAtLogin = SMAppService.mainApp.status == .enabled
            appState.startupStatusMessage = "Could not update login item"
        }
    }

    func setDefaultShortcut(_ shortcut: String) {
        appState.defaultShortcut = shortcut
        configureGlobalShortcut(shortcut)
    }

    // MARK: - Agent (Push-to-Talk)

    /// Push-to-talk toggle: first press starts listening, second press stops and processes.
    func activateAgentListening() {
        if appState.agentPhase == .listening {
            // Second press — stop and process
            stopAndProcess()
            return
        }

        // First press — start listening
        appState.isNotchVisible = true
        notchWindowController.show()
        appState.agentTranscript = ""
        appState.agentCacheHit = false

        // Apply current settings to provider
        aiManager.configureOllama(
            baseURL: appState.ollamaBaseURL,
            model: appState.ollamaModel
        )
        configureSpeechRecognition()

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.aiManager.activate(playSounds: self.appState.agentPlaySounds)
        }
    }

    /// Stop listening and send transcript through the AI pipeline.
    func stopAndProcess() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.aiManager.processCommand(
                providerName: self.appState.selectedProvider,
                defaultMusicApp: self.appState.selectedMusicProvider,
                cacheEnabled: self.appState.cacheEnabled,
                playSounds: self.appState.agentPlaySounds,
                voiceFeedback: self.appState.agentVoiceFeedback
            )
        }
    }

    /// Execute the last parsed command.
    func executeLastCommand() {
        guard let command = aiManager.lastCommand else { return }
        aiManager.executeCommand(command)
    }

    /// Stop everything and reset agent to idle.
    func resetAgent() {
        aiManager.reset()
        appState.agentInputLevel = 0
        appState.agentTranscript = ""
        appState.agentCacheHit = false
        appState.agentPhase = .idle
    }

    private func configureSpeechRecognition() {
        aiManager.configureSpeechRecognition(
            engine: appState.speechRecognitionEngine,
            whisperExecutablePath: "",
            whisperModelPath: appState.whisperModelPath
        )
    }

    func chooseWhisperModel() {
        let panel = NSOpenPanel()
        panel.title = "Choose Whisper Model"
        panel.message = "Select a ggml Whisper model (.bin)"
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let binType = UTType(filenameExtension: "bin") {
            panel.allowedContentTypes = [binType]
        }

        if panel.runModal() == .OK, let url = panel.url {
            appState.whisperModelPath = url.path
            appState.whisperStatusMessage = "Model selected"
            configureSpeechRecognition()
        }
    }

    func testWhisperConfiguration() {
        let configuration = SpeechRecognitionConfiguration(
            engine: SpeechRecognitionEngine(rawValue: appState.speechRecognitionEngine) ?? .automatic,
            whisperExecutablePath: "",
            whisperModelPath: appState.whisperModelPath
        )

        do {
            let executableURL = try configuration.resolvedWhisperExecutableURL()
            let modelURL = try configuration.resolvedWhisperModelURL()
            try WhisperCppRunner.testExecutable(executableURL: executableURL)
            appState.whisperStatusMessage = "Ready: \(executableURL.path) + \(modelURL.lastPathComponent)"
            configureSpeechRecognition()
        } catch {
            appState.whisperStatusMessage = error.localizedDescription
        }
    }

    // MARK: - Ollama Health

    func checkOllamaHealth() async {
        let available = await aiManager.checkProviderHealth(named: "Ollama")
        appState.ollamaIsAvailable = available

        if available {
            let models = await aiManager.fetchOllamaModels()
            appState.ollamaAvailableModels = models
        }
    }

    func clearCommandCache() {
        aiManager.clearCache()
        appState.cacheEntryCount = 0
    }

    // MARK: - Updates

    func checkForUpdates(force: Bool = false) {
        guard !appState.updateCheckInProgress else { return }

        appState.updateCheckInProgress = true
        appState.updateStatusMessage = force ? "Checking for updates..." : appState.updateStatusMessage

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let result = try await UpdateChecker.checkForUpdates()
                self.appState.lastUpdateCheckDate = Date()
                self.appState.availableVersion = result.latestVersion
                self.appState.updateReleaseURL = result.releaseURL
                self.appState.isUpdateAvailable = result.isUpdateAvailable
                self.appState.updateStatusMessage = result.isUpdateAvailable
                    ? "Version \(result.latestVersion) is available"
                    : "NotchAgent is up to date"
            } catch {
                self.appState.updateStatusMessage = "Could not check for updates"
            }

            self.appState.updateCheckInProgress = false
        }
    }

    func openLatestRelease() {
        guard let url = appState.updateReleaseURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func checkForUpdatesIfNeeded() {
        let now = Date()
        if let lastCheck = appState.lastUpdateCheckDate,
           now.timeIntervalSince(lastCheck) < 24 * 60 * 60 {
            return
        }

        checkForUpdates()
    }

    private func refreshLoginItemStatus() {
        let isEnabled = SMAppService.mainApp.status == .enabled
        appState.openAtLogin = isEnabled
        appState.startupStatusMessage = isEnabled ? "Enabled" : "Disabled"
    }

    // MARK: - Global Shortcut

    private func configureGlobalShortcut(_ shortcut: String) {
        unregisterShortcut()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }

                let coordinator = Unmanaged<AppCoordinator>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    coordinator.activateAgentListening()
                }

                return noErr
            },
            1,
            &eventType,
            userData,
            &shortcutEventHandler
        )

        let hotKeyID = EventHotKeyID(signature: 0x4E544348, id: 1)
        let status = RegisterEventHotKey(
            49,
            carbonModifiers(for: shortcut),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &shortcutRef
        )

        appState.shortcutStatusMessage = status == noErr
            ? "\(shortcut) opens agent listening"
            : "Shortcut unavailable"
    }

    private func unregisterShortcut() {
        if let shortcutRef {
            UnregisterEventHotKey(shortcutRef)
            self.shortcutRef = nil
        }

        if let shortcutEventHandler {
            RemoveEventHandler(shortcutEventHandler)
            self.shortcutEventHandler = nil
        }
    }

    private func carbonModifiers(for shortcut: String) -> UInt32 {
        switch shortcut {
        case "Command + Space":
            UInt32(cmdKey)
        case "Control + Space":
            UInt32(controlKey)
        default:
            UInt32(optionKey)
        }
    }
}
