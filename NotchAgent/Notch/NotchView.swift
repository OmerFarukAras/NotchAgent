//
//  NotchView.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Root orchestrator for the notch UI.
///
/// Design rule: the top bar (compact bar) sits at a FIXED Y position.
/// The notch only expands horizontally and downward — never pushes the top bar.
struct NotchView: View {
    var viewModel: NotchViewModel
    var onHideNotch: () -> Void

    private var appState: AppState { viewModel.appState }

    var body: some View {
        ZStack(alignment: .top) {
            // Full-window tap target for outside-click dismissal
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.handleOutsideClick()
                }

            // Notch body
            notchBody
                .frame(width: viewModel.notchWidth, height: viewModel.notchHeight)
                .background {
                    NotchBodyShape(bottomRadius: viewModel.bottomRadius)
                        .fill(Design.Colors.notchBackground)
                        .shadow(
                            color: .black.opacity(viewModel.shadowOpacity),
                            radius: viewModel.shadowRadius,
                            y: viewModel.shadowY
                        )
                }
                .notchGlow(
                    color: viewModel.glowColor,
                    isActive: viewModel.isGlowActive
                )
                .contentShape(NotchBodyShape(bottomRadius: viewModel.bottomRadius))
                .onTapGesture {
                    viewModel.handleNotchTap()
                }
                .contextMenu {
                    SettingsLink {
                        Text("Settings")
                    }
                    Button("Hide Notch") {
                        onHideNotch()
                    }
                }
        }
        .frame(
            width: Design.Sizes.windowWidth,
            height: Design.Sizes.windowHeight,
            alignment: .top
        )
        .animation(.surfaceTransition, value: appState.activeSurface)
        .animation(.surfaceTransition, value: appState.isSurfaceExpanded)
        .animation(.notchExpand, value: appState.isNotchExpanded)
        .animation(.stateChange, value: appState.notchState)
    }

    // MARK: - Body

    private var notchBody: some View {
        VStack(spacing: viewModel.verticalSpacing) {
            NotchCompactBar(
                state: appState.notchState,
                isExpanded: appState.isNotchExpanded,
                activeSurface: appState.activeSurface,
                showSpotifyStatus: appState.showSpotifyStatus,
                spotifyIsPlaying: appState.spotifyIsPlaying,
                spotifyArtworkData: appState.spotifyArtworkData,
                compactMediaIconStyle: appState.compactMediaIconStyle,
                showMirrorWidget: appState.showMirrorWidget,
                showCalendarWidget: appState.showCalendarWidget,
                showWeatherWidget: appState.showWeatherWidget,
                onMediaTap: { viewModel.toggleSurface(.spotify) },
                onMirrorTap: { viewModel.toggleSurface(.mirror) },
                onCalendarTap: { viewModel.toggleSurface(.calendar) },
                onWeatherTap: { viewModel.toggleSurface(.weather) },
                onAgentTap: { viewModel.toggleSurface(.agent) }
            )

            // Active surface
            if appState.activeSurface != .none {
                SurfaceContainer(
                    activeSurface: appState.activeSurface,
                    appState: appState,
                    onSpotifyOpen: { viewModel.openSpotify() },
                    onSpotifyPrevious: { viewModel.skipSpotifyBackward() },
                    onSpotifyPlayPause: { viewModel.toggleSpotifyPlayback() },
                    onSpotifyNext: { viewModel.skipSpotifyForward() },
                    onSpotifyToggleShuffle: { viewModel.toggleSpotifyShuffle() },
                    onSpotifyToggleRepeat: { viewModel.toggleSpotifyRepeat() },
                    onSpotifyVolumeChange: { volume in viewModel.setSpotifyVolume(to: volume) },
                    onCalendarDayTap: { date in viewModel.openCalendar(at: date) },
                    onWeatherTap: { viewModel.openWeatherApp() },
                    onAgentListen: {
                        viewModel.setAgentState(.listening, message: "Listening for a command")
                    },
                    onAgentThink: {
                        viewModel.setAgentState(.thinking, message: "Routing with \(appState.routerModel.lowercased())")
                    },
                    onAgentRun: { viewModel.runDemoFlow() },
                    onAgentReset: { viewModel.resetAgent() }
                )
                .frame(height: viewModel.surfaceContentHeight)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, viewModel.horizontalPadding)
        .padding(.top, viewModel.topPadding)
        .padding(.bottom, viewModel.bottomPadding)
    }
}
