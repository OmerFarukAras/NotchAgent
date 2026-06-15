//
//  NotchViewModel.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI
import AppKit
import EventKit

/// Coordinates notch UI behavior — layout calculations, surface management,
/// glow logic, and demo flow orchestration.
///
/// Key design rule: **top padding never changes**. The compact bar stays at
/// the exact same Y position in compact, expanded, and surface-open states.
@MainActor @Observable
final class NotchViewModel {
    let appState: AppState

    private var demoTask: Task<Void, Never>?
    private var spotifyRefreshTask: Task<Void, Never>?
    private var spotifyArtworkTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
        startSpotifyRefresh()
        fetchNextCalendarEvent()
    }

    // MARK: - Layout

    var notchWidth: CGFloat {
        if appState.isSurfaceExpanded {
            Design.Sizes.detailedWidth
        } else {
            appState.isNotchExpanded ? Design.Sizes.expandedWidth : Design.Sizes.compactWidth
        }
    }

    var notchHeight: CGFloat {
        if appState.activeSurface == .none {
            Design.Sizes.compactHeight
        } else {
            Design.Sizes.compactHeight
                + Design.Spacing.surfaceVerticalSpacing
                + surfaceContentHeight
                + Design.Spacing.surfaceBottom
                - Design.Spacing.compactBottom
        }
    }

    var surfaceContentHeight: CGFloat {
        if appState.isSurfaceExpanded {
            switch appState.activeSurface {
            case .none: 0
            case .spotify: Design.Sizes.spotifyDetailedContentHeight
            case .mirror: Design.Sizes.mirrorDetailedContentHeight
            case .calendar: Design.Sizes.calendarDetailedContentHeight
            case .weather: Design.Sizes.weatherDetailedContentHeight
            case .agent: Design.Sizes.agentContentHeight
            }
        } else {
            switch appState.activeSurface {
            case .none: 0
            case .spotify: Design.Sizes.spotifyContentHeight
            case .mirror: Design.Sizes.mirrorContentHeight
            case .calendar: Design.Sizes.calendarContentHeight
            case .weather: Design.Sizes.weatherContentHeight
            case .agent: Design.Sizes.agentContentHeight
            }
        }
    }

    var verticalSpacing: CGFloat {
        appState.activeSurface != .none
            ? Design.Spacing.surfaceVerticalSpacing
            : 0
    }

    var horizontalPadding: CGFloat {
        appState.isNotchExpanded
            ? Design.Spacing.expandedHorizontal
            : Design.Spacing.compactHorizontal
    }

    /// Top padding is CONSTANT — the compact bar never moves vertically.
    var topPadding: CGFloat {
        Design.Spacing.compactTop
    }

    var bottomPadding: CGFloat {
        appState.activeSurface != .none
            ? Design.Spacing.surfaceBottom
            : Design.Spacing.compactBottom
    }

    // MARK: - Shape

    var bottomRadius: CGFloat {
        appState.activeSurface != .none
            ? Design.Radii.notchBottomExpanded
            : Design.Radii.notchBottomCompact
    }

    // MARK: - Shadow

    var shadowRadius: CGFloat {
        appState.activeSurface != .none
            ? Design.Shadows.expandedRadius
            : Design.Shadows.compactRadius
    }

    var shadowY: CGFloat {
        appState.activeSurface != .none
            ? Design.Shadows.expandedY
            : Design.Shadows.compactY
    }

    var shadowOpacity: Double {
        appState.activeSurface != .none
            ? Design.Shadows.expandedOpacity
            : Design.Shadows.compactOpacity
    }

    // MARK: - Glow

    var glowColor: Color {
        switch appState.accentBehavior {
        case "Album art":
            appState.activeSurface == .spotify ? .green : .clear
        case "Agent state":
            Design.Colors.stateColor(for: appState.notchState)
        default:
            .clear
        }
    }

    var isGlowActive: Bool {
        appState.activeSurface != .none && appState.accentBehavior != "Static black"
    }

    // MARK: - Window

    var windowSize: NSSize {
        NSSize(width: Design.Sizes.windowWidth, height: Design.Sizes.windowHeight)
    }

    // MARK: - Actions

    /// Tapping the notch body — expands/collapses, or closes active surface.
    func handleNotchTap() {
        if appState.activeSurface != .none {
            // Close surface but stay expanded
            appState.activeSurface = .none
            appState.isSurfaceExpanded = false
            return
        }

        appState.isNotchExpanded.toggle()

        if !appState.isNotchExpanded {
            demoTask?.cancel()
            appState.notchState = .idle
        }
    }

    /// Generic surface toggle — tapping a feature icon opens/closes its surface.
    func toggleSurface(_ surface: NotchSurface) {
        demoTask?.cancel()
        if appState.activeSurface == surface {
            if appState.isSurfaceExpanded {
                // Close this surface, stay expanded
                appState.activeSurface = .none
                appState.isSurfaceExpanded = false
                stopSpotifyRefresh()
            } else {
                appState.isSurfaceExpanded = true
            }
        } else {
            // Open new surface
            appState.activeSurface = surface
            appState.isNotchExpanded = true
            appState.isSurfaceExpanded = false
            if surface == .spotify {
                refreshSpotifyState()
                startSpotifyRefresh()
            } else {
                stopSpotifyRefresh()
            }
        }
    }

    /// Outside click — close everything except mirror (so user can adjust camera settings in control center).
    func handleOutsideClick() {
        guard appState.closeSurfaceOnOutsideClick else { return }
        guard appState.activeSurface != .mirror else { return }
        guard appState.activeSurface != .none || appState.isNotchExpanded else { return }
        closeSurface()
    }

    /// Full close — surface + collapse.
    func closeSurface() {
        appState.activeSurface = .none
        appState.isNotchExpanded = false
        appState.isSurfaceExpanded = false
        appState.notchState = .idle
        stopSpotifyRefresh()
    }

    func runDemoFlow() {
        demoTask?.cancel()
        appState.activeSurface = .none
        appState.isNotchExpanded = true
        appState.isSurfaceExpanded = false
        appState.notchState = .listening
        appState.agentStatusMessage = "Listening for a command"

        demoTask = Task { [weak self] in
            try? await Task.sleep(for: Motion.demoListeningDuration)

            guard !Task.isCancelled else { return }
            self?.appState.notchState = .thinking
            self?.appState.agentStatusMessage = "Routing with rules first"

            try? await Task.sleep(for: .milliseconds(650))

            guard !Task.isCancelled else { return }
            self?.appState.notchState = .result
            self?.appState.agentStatusMessage = "Command handled locally"

            try? await Task.sleep(for: Motion.demoResultDuration)

            guard !Task.isCancelled else { return }
            self?.appState.notchState = .idle
            self?.appState.isNotchExpanded = false
            self?.appState.agentStatusMessage = "Ready for a quick command"
        }
    }

    func setAgentState(_ state: NotchState, message: String) {
        demoTask?.cancel()
        appState.activeSurface = .agent
        appState.isNotchExpanded = true
        appState.isSurfaceExpanded = false
        appState.notchState = state
        appState.agentStatusMessage = message
    }

    func resetAgent() {
        demoTask?.cancel()
        appState.notchState = .idle
        appState.agentStatusMessage = "Ready for a quick command"
    }

    func openSpotify() {
        appState.spotifyStatusMessage = "Opening Spotify"
        guard let spotifyURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.spotify.client"
        ) else {
            appState.spotifyStatusMessage = "Spotify not found"
            appState.notchState = .error
            appState.agentStatusMessage = "Spotify app could not be opened"
            return
        }

        NSWorkspace.shared.openApplication(
            at: spotifyURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { [weak self] _, error in
            Task { @MainActor [weak self] in
                if error == nil {
                    self?.appState.spotifyStatusMessage = "Spotify opened"
                    self?.appState.notchState = .result
                    self?.refreshSpotifyState()
                } else {
                    self?.appState.spotifyStatusMessage = "Spotify could not open"
                    self?.appState.notchState = .error
                    self?.appState.agentStatusMessage = "Spotify app could not be opened"
                }
            }
        }
    }

    func toggleSpotifyPlayback() {
        runSpotifyCommand("playpause")
        refreshSpotifyState(after: .milliseconds(250))
        appState.notchState = .result
    }

    func skipSpotifyForward() {
        runSpotifyCommand("next track")
        refreshSpotifyState(after: .milliseconds(450))
        if appState.spotifyStatusMessage == "Ready" {
            appState.spotifyStatusMessage = "Skipped forward"
        }
        appState.notchState = .result
    }

    func skipSpotifyBackward() {
        runSpotifyCommand("previous track")
        refreshSpotifyState(after: .milliseconds(450))
        if appState.spotifyStatusMessage == "Ready" {
            appState.spotifyStatusMessage = "Skipped back"
        }
        appState.notchState = .result
    }

    func refreshSpotifyState() {
        let source = """
        tell application "System Events"
            set isSpotifyRunning to exists process "Spotify"
        end tell

        if isSpotifyRunning is false then
            return "not-running"
        end if

        tell application "Spotify"
            set trackName to "No track"
            set artistName to "Spotify"
            set playbackState to player state as text
            set currentPosition to player position
            set trackDuration to 0
            set artworkURL to ""
            set currentVolume to 50
            set isShuffling to false
            set isRepeating to false

            try
                set trackName to name of current track
                set artistName to artist of current track
                set trackDuration to duration of current track
                set artworkURL to artwork url of current track
                set currentVolume to sound volume
                set isShuffling to shuffling
                set isRepeating to repeating
            end try

            return trackName & linefeed & artistName & linefeed & playbackState & linefeed & (currentPosition as text) & linefeed & (trackDuration as text) & linefeed & artworkURL & linefeed & (currentVolume as text) & linefeed & (isShuffling as text) & linefeed & (isRepeating as text)
        end tell
        """

        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error),
              error == nil,
              let value = result.stringValue
        else {
            appState.spotifyStatusMessage = "Spotify automation needs permission"
            appState.notchState = .error
            appState.agentStatusMessage = "Allow Automation access for Spotify controls"
            return
        }

        guard value != "not-running" else {
            appState.spotifyStatusMessage = "Spotify is closed"
            appState.spotifyIsPlaying = false
            appState.spotifyProgress = 0
            appState.spotifyArtworkURL = ""
            appState.spotifyArtworkData = nil
            return
        }

        let parts = value.components(separatedBy: "\n")
        guard parts.count >= 5 else { return }

        appState.spotifyTrackTitle = parts[0]
        appState.spotifyArtistName = parts[1]
        appState.spotifyIsPlaying = parts[2] == "playing"

        let currentPosition = Double(parts[3]) ?? 0
        let durationSeconds = (Double(parts[4]) ?? 0) / 1000
        appState.spotifyProgress = durationSeconds > 0
            ? min(max(currentPosition / durationSeconds, 0), 1)
            : 0
        appState.spotifyStatusMessage = appState.spotifyIsPlaying ? "Playing" : "Paused"

        let artworkURL = parts.count >= 6 ? parts[5] : ""
        updateSpotifyArtwork(from: artworkURL)

        if parts.count >= 7, let vol = Double(parts[6]) {
            appState.spotifyVolume = vol / 100.0
        }
        
        if parts.count >= 9 {
            appState.spotifyIsShuffling = parts[7] == "true"
            appState.spotifyIsRepeating = parts[8] == "true"
        }
    }

    private func refreshSpotifyState(after delay: Duration) {
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.refreshSpotifyState()
        }
    }

    private func startSpotifyRefresh() {
        spotifyRefreshTask?.cancel()
        spotifyRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.refreshSpotifyState()
            }
        }
    }

    private func stopSpotifyRefresh() {
        spotifyRefreshTask?.cancel()
        spotifyRefreshTask = nil
    }

    private func updateSpotifyArtwork(from artworkURL: String) {
        guard appState.spotifyArtworkURL != artworkURL else { return }

        spotifyArtworkTask?.cancel()
        appState.spotifyArtworkURL = artworkURL
        appState.spotifyArtworkData = nil

        guard let url = URL(string: artworkURL), !artworkURL.isEmpty else { return }

        spotifyArtworkTask = Task { [weak self] in
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  !Task.isCancelled,
                  (response as? HTTPURLResponse)?.statusCode == 200
            else { return }

            await MainActor.run {
                guard self?.appState.spotifyArtworkURL == artworkURL else { return }
                self?.appState.spotifyArtworkData = data
            }
        }
    }

    private func runSpotifyCommand(_ command: String) {
        let source = """
        tell application "Spotify"
            \(command)
        end tell
        """

        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)

        if error != nil {
            appState.spotifyStatusMessage = "Spotify automation needs permission"
            appState.notchState = .error
            appState.agentStatusMessage = "Allow Automation access for Spotify controls"
        }
    }

    func setSpotifyVolume(to value: Double) {
        let intVol = Int(value * 100)
        runSpotifyCommand("set sound volume to \(intVol)")
        appState.spotifyVolume = value
    }

    func toggleSpotifyShuffle() {
        runSpotifyCommand("set shuffling to not shuffling")
        refreshSpotifyState(after: .milliseconds(500))
    }

    func toggleSpotifyRepeat() {
        runSpotifyCommand("set repeating to not repeating")
        refreshSpotifyState(after: .milliseconds(500))
    }
    
    func openCalendar(at date: Date) {
        let interval = date.timeIntervalSinceReferenceDate
        if let url = URL(string: "ical://?action=show&date=\(interval)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openWeatherApp() {
        if let url = URL(string: "weather://") {
            NSWorkspace.shared.open(url)
        }
    }

    func fetchNextCalendarEvent() {
        guard appState.syncAppleCalendar else {
            appState.calendarNextEventTitle = "No Upcoming Event"
            appState.calendarNextEventTime = ""
            return
        }

        let store = EKEventStore()
        
        let fetchBlock: @Sendable (Bool, Error?) -> Void = { [weak self] granted, _ in
            guard granted else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }

                let allCalendars = store.calendars(for: .event)
                let now = Date()

                guard let monthStart = Calendar.current.date(byAdding: .month, value: -1, to: now),
                      let monthEnd = Calendar.current.date(byAdding: .month, value: 2, to: now),
                      let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now) else { return }

                let monthPredicate = store.predicateForEvents(withStart: monthStart, end: monthEnd, calendars: allCalendars)
                let monthEvents = store.events(matching: monthPredicate)

                var eventDays = Set<String>()
                var holidayDays = Set<String>()
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"

                var nextEvent: EKEvent?

                for event in monthEvents {
                    let isHoliday = event.calendar.title.lowercased().contains("holiday") ||
                                    event.calendar.title.lowercased().contains("bayram") ||
                                    event.calendar.title.lowercased().contains("siri") ||
                                    event.calendar.type == .birthday

                    let dayStr = df.string(from: event.startDate)
                    if isHoliday {
                        holidayDays.insert(dayStr)
                    } else {
                        eventDays.insert(dayStr)

                        if event.endDate > now && event.startDate < nextWeek {
                            if let currentNext = nextEvent {
                                if event.startDate < currentNext.startDate {
                                    nextEvent = event
                                }
                            } else {
                                nextEvent = event
                            }
                        }
                    }
                }

                let titleStr = nextEvent?.title ?? "No Upcoming Event"
                let timeStr: String
                if let ev = nextEvent {
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    timeStr = ev.isAllDay ? "All Day" : formatter.string(from: ev.startDate)
                } else {
                    timeStr = ""
                }

                self.appState.calendarNextEventTitle = titleStr
                self.appState.calendarNextEventTime = timeStr
                self.appState.eventDays = eventDays
                self.appState.holidayDays = holidayDays
            }
        }
        
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: fetchBlock)
        } else {
            store.requestAccess(to: .event, completion: fetchBlock)
        }
    }
}
