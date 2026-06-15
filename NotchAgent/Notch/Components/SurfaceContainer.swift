//
//  SurfaceContainer.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Hosts the currently active surface inside the expanded notch.
///
/// Handles transitions between surfaces. New surfaces are added here.
struct SurfaceContainer: View {
    let activeSurface: NotchSurface
    let appState: AppState
    let onSpotifyOpen: () -> Void
    let onSpotifyPrevious: () -> Void
    let onSpotifyPlayPause: () -> Void
    let onSpotifyNext: () -> Void
    let onSpotifyToggleShuffle: () -> Void
    let onSpotifyToggleRepeat: () -> Void
    let onSpotifyVolumeChange: (Double) -> Void
    let onCalendarDayTap: (Date) -> Void
    let onWeatherTap: () -> Void
    let onAgentListen: () -> Void
    let onAgentThink: () -> Void
    let onAgentRun: () -> Void
    let onAgentReset: () -> Void

    var body: some View {
        Group {
            switch activeSurface {
            case .none:
                EmptyView()
            case .spotify:
                SpotifySurface(
                    title: appState.spotifyTrackTitle,
                    artist: appState.spotifyArtistName,
                    isPlaying: appState.spotifyIsPlaying,
                    progress: appState.spotifyProgress,
                    status: appState.spotifyStatusMessage,
                    artworkData: appState.spotifyArtworkData,
                    volume: appState.spotifyVolume,
                    isShuffling: appState.spotifyIsShuffling,
                    isRepeating: appState.spotifyIsRepeating,
                    isExpanded: appState.isSurfaceExpanded,
                    onOpen: onSpotifyOpen,
                    onPrevious: onSpotifyPrevious,
                    onPlayPause: onSpotifyPlayPause,
                    onNext: onSpotifyNext,
                    onToggleShuffle: onSpotifyToggleShuffle,
                    onToggleRepeat: onSpotifyToggleRepeat,
                    onVolumeChange: onSpotifyVolumeChange
                )
                    .transition(.opacity)
            case .mirror:
                MirrorSurface(
                    isExpanded: appState.isSurfaceExpanded,
                    selectedCameraID: appState.selectedCameraID
                )
                .transition(.opacity)
            case .calendar:
                CalendarSurface(
                    isExpanded: appState.isSurfaceExpanded,
                    nextEventTitle: appState.calendarNextEventTitle,
                    nextEventTime: appState.calendarNextEventTime,
                    eventDays: appState.eventDays,
                    holidayDays: appState.holidayDays,
                    onDayTap: onCalendarDayTap
                )
                    .transition(.opacity)
            case .weather:
                WeatherSurface(
                    isExpanded: appState.isSurfaceExpanded,
                    onTap: onWeatherTap
                )
                    .transition(.opacity)
            case .agent:
                AgentSurface(
                    state: appState.notchState,
                    message: appState.agentStatusMessage,
                    routerMode: appState.routerModel,
                    onListen: onAgentListen,
                    onThink: onAgentThink,
                    onRun: onAgentRun,
                    onReset: onAgentReset
                )
                    .transition(.opacity)
            }
        }
    }
}
