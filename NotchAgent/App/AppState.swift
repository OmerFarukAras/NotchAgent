//
//  AppState.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Foundation

/// Single source of truth for application data.
///
/// Pure data store — no business logic, no computed presentation values.
/// Business logic lives in `NotchViewModel`; presentation lives in components.
@MainActor @Observable
final class AppState {
    // MARK: - Notch State

    var notchState: NotchState = .idle
    var isNotchExpanded = false
    var isNotchVisible = true
    var activeSurface: NotchSurface = .none
    var isSurfaceExpanded = false

    // MARK: - Enums
    
    enum MusicProvider: String, CaseIterable, Identifiable {
        case spotify = "Spotify"
        case appleMusic = "Apple Music"

        var id: String { rawValue }

        var bundleIdentifier: String {
            switch self {
            case .spotify:
                return "com.spotify.client"
            case .appleMusic:
                return "com.apple.Music"
            }
        }

        var processName: String {
            switch self {
            case .spotify:
                return "Spotify"
            case .appleMusic:
                return "Music"
            }
        }

        var scriptName: String {
            switch self {
            case .spotify:
                return "Spotify"
            case .appleMusic:
                return "Music"
            }
        }
    }

    enum CompactMediaIconStyle: String, CaseIterable, Identifiable {
        case equalizer = "Live Equalizer"
        case albumArt = "Album Art"
        case musicNote = "Music Note"
        
        var id: String { rawValue }
    }

    // MARK: - Feature Toggles

    var showSpotifyStatus: Bool = UserDefaults.standard.object(forKey: "showSpotifyStatus") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showSpotifyStatus, forKey: "showSpotifyStatus") }
    }
    
    var showMirrorWidget: Bool = UserDefaults.standard.object(forKey: "showMirrorWidget") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showMirrorWidget, forKey: "showMirrorWidget") }
    }
    
    var showCalendarWidget: Bool = UserDefaults.standard.object(forKey: "showCalendarWidget") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showCalendarWidget, forKey: "showCalendarWidget") }
    }
    
    var showWeatherWidget: Bool = UserDefaults.standard.object(forKey: "showWeatherWidget") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showWeatherWidget, forKey: "showWeatherWidget") }
    }

    // MARK: - Music

    var selectedMusicProvider: String = UserDefaults.standard.string(forKey: "selectedMusicProvider") ?? MusicProvider.spotify.rawValue {
        didSet { UserDefaults.standard.set(selectedMusicProvider, forKey: "selectedMusicProvider") }
    }

    var spotifyTrackTitle = "Midnight City"
    var spotifyArtistName = "M83"
    var spotifyIsPlaying = false
    var spotifyProgress: Double = 0.42
    var spotifyStatusMessage = "Ready"
    var spotifyArtworkURL = ""
    var spotifyArtworkData: Data?
    var spotifyVolume: Double = 0.50
    var spotifyIsShuffling = false
    var spotifyIsRepeating = false
    
    var compactMediaIconStyle: String = UserDefaults.standard.string(forKey: "compactMediaIconStyle") ?? CompactMediaIconStyle.albumArt.rawValue {
        didSet { UserDefaults.standard.set(compactMediaIconStyle, forKey: "compactMediaIconStyle") }
    }

    // MARK: - Agent

    var agentStatusMessage = "Ready for a quick command"
    var agentInputLevel: Double = 0

    // MARK: - Agent AI Pipeline

    var agentTranscript = ""
    var agentPhase: AgentPhase = .idle
    var agentLastResponse = ""
    var agentLastLatencyMs: Int = 0
    var agentError: String?
    var agentCacheHit = false

    // MARK: - AI Provider Settings

    var selectedProvider: String = UserDefaults.standard.string(forKey: "selectedProvider") ?? "Ollama" {
        didSet { UserDefaults.standard.set(selectedProvider, forKey: "selectedProvider") }
    }

    var ollamaBaseURL: String = UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434" {
        didSet { UserDefaults.standard.set(ollamaBaseURL, forKey: "ollamaBaseURL") }
    }

    var ollamaModel: String = UserDefaults.standard.string(forKey: "ollamaModel") ?? "qwen2.5:3b" {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: "ollamaModel") }
    }

    var ollamaIsAvailable = false
    var ollamaAvailableModels: [String] = []

    var openAIAPIKey: String = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? "" {
        didSet { UserDefaults.standard.set(openAIAPIKey, forKey: "openAIAPIKey") }
    }

    var cacheEnabled: Bool = UserDefaults.standard.object(forKey: "cacheEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(cacheEnabled, forKey: "cacheEnabled") }
    }

    var cacheEntryCount: Int = 0

    // MARK: - AI Experience Settings

    var agentSilenceDetection: Bool = UserDefaults.standard.object(forKey: "agentSilenceDetection") as? Bool ?? true {
        didSet { UserDefaults.standard.set(agentSilenceDetection, forKey: "agentSilenceDetection") }
    }

    var agentVoiceFeedback: Bool = UserDefaults.standard.object(forKey: "agentVoiceFeedback") as? Bool ?? true {
        didSet { UserDefaults.standard.set(agentVoiceFeedback, forKey: "agentVoiceFeedback") }
    }

    var agentPlaySounds: Bool = UserDefaults.standard.object(forKey: "agentPlaySounds") as? Bool ?? true {
        didSet { UserDefaults.standard.set(agentPlaySounds, forKey: "agentPlaySounds") }
    }

    var speechRecognitionEngine: String = UserDefaults.standard.string(forKey: "speechRecognitionEngine") ?? SpeechRecognitionEngine.appleSpeech.rawValue {
        didSet { UserDefaults.standard.set(speechRecognitionEngine, forKey: "speechRecognitionEngine") }
    }

    var whisperExecutablePath: String = UserDefaults.standard.string(forKey: "whisperExecutablePath") ?? "" {
        didSet { UserDefaults.standard.set(whisperExecutablePath, forKey: "whisperExecutablePath") }
    }

    var whisperModelPath: String = UserDefaults.standard.string(forKey: "whisperModelPath") ?? "" {
        didSet { UserDefaults.standard.set(whisperModelPath, forKey: "whisperModelPath") }
    }

    var whisperStatusMessage = "Not checked"

    // MARK: - Settings

    var closeSurfaceOnOutsideClick: Bool = UserDefaults.standard.object(forKey: "closeSurfaceOnOutsideClick") as? Bool ?? true {
        didSet { UserDefaults.standard.set(closeSurfaceOnOutsideClick, forKey: "closeSurfaceOnOutsideClick") }
    }
    
    var openAtLogin: Bool = UserDefaults.standard.object(forKey: "openAtLogin") as? Bool ?? false {
        didSet { UserDefaults.standard.set(openAtLogin, forKey: "openAtLogin") }
    }
    
    var defaultShortcut: String = UserDefaults.standard.string(forKey: "defaultShortcut") ?? "Option + Space" {
        didSet { UserDefaults.standard.set(defaultShortcut, forKey: "defaultShortcut") }
    }
    
    var startupStatusMessage = "Disabled"
    var shortcutStatusMessage = "Option + Space active"

    var updateStatusMessage = "Not checked yet"
    var updateCheckInProgress = false
    var isUpdateAvailable = false
    var availableVersion = ""
    var updateReleaseURL: URL?
    var lastUpdateCheckDate: Date? = UserDefaults.standard.object(forKey: "lastUpdateCheckDate") as? Date {
        didSet {
            if let lastUpdateCheckDate {
                UserDefaults.standard.set(lastUpdateCheckDate, forKey: "lastUpdateCheckDate")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastUpdateCheckDate")
            }
        }
    }
    
    var routerModel: String = UserDefaults.standard.string(forKey: "routerModel") ?? "Rules first" {
        didSet { UserDefaults.standard.set(routerModel, forKey: "routerModel") }
    }
    
    var accentBehavior: String = UserDefaults.standard.string(forKey: "accentBehavior") ?? "Album art" {
        didSet { UserDefaults.standard.set(accentBehavior, forKey: "accentBehavior") }
    }
    
    var selectedCameraID: String = UserDefaults.standard.string(forKey: "selectedCameraID") ?? "" {
        didSet { UserDefaults.standard.set(selectedCameraID, forKey: "selectedCameraID") }
    }
    
    var syncAppleCalendar: Bool = UserDefaults.standard.object(forKey: "syncAppleCalendar") as? Bool ?? true {
        didSet { UserDefaults.standard.set(syncAppleCalendar, forKey: "syncAppleCalendar") }
    }
    
    var weatherLocation: String = UserDefaults.standard.string(forKey: "weatherLocation") ?? "" {
        didSet { UserDefaults.standard.set(weatherLocation, forKey: "weatherLocation") }
    }
    var calendarNextEventTitle = "No Upcoming Event"
    var calendarNextEventTime = ""
    var eventDays: Set<String> = []
    var holidayDays: Set<String> = []

    init() {
        UserDefaults.standard.removeObject(forKey: "isNotchVisible")
        if !UserDefaults.standard.bool(forKey: "speechRecognitionDefaultMigratedToApple"),
           speechRecognitionEngine == SpeechRecognitionEngine.automatic.rawValue {
            speechRecognitionEngine = SpeechRecognitionEngine.appleSpeech.rawValue
            UserDefaults.standard.set(true, forKey: "speechRecognitionDefaultMigratedToApple")
        }
    }
}

enum NotchSurface {
    case none
    case spotify
    case mirror
    case calendar
    case weather
    case agent
}

/// Pipeline phase for the AI command system.
enum AgentPhase: String {
    case idle
    case listening
    case processing
    case executing
    case done
    case error
}
