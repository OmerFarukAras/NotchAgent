//
//  NotchCompactBar.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Top bar of the notch — position and height NEVER change.
///
/// Compact:  `[music] ——[notch]—— [AI]`
/// Expanded: `[music][calendar][weather] ——[notch]—— [mirror][AI]`
///
/// Feature icons fade into the side wings when expanded.
/// Each feature icon toggles its surface when tapped.
struct NotchCompactBar: View {
    let state: NotchState
    let isExpanded: Bool
    let activeSurface: NotchSurface
    let showSpotifyStatus: Bool
    let spotifyIsPlaying: Bool
    let spotifyArtworkData: Data?
    let compactMediaIconStyle: String
    let showMirrorWidget: Bool
    let showCalendarWidget: Bool
    let showWeatherWidget: Bool
    let onMediaTap: () -> Void
    let onMirrorTap: () -> Void
    let onCalendarTap: () -> Void
    let onWeatherTap: () -> Void
    let onAgentTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            leftWing

            Spacer(minLength: 0)

            // Center: physical notch area
            cameraSpace

            Spacer(minLength: 0)

            rightWing
        }
        .frame(height: Design.Sizes.compactBarHeight)
    }

    // MARK: - Feature Icons

    @ViewBuilder
    private var leftFeatureIcons: some View {
        if showCalendarWidget {
            featureIcon("calendar", surface: .calendar, action: onCalendarTap)
        }
        if showWeatherWidget {
            featureIcon("cloud.sun.fill", surface: .weather, action: onWeatherTap)
        }
    }

    @ViewBuilder
    private var rightFeatureIcons: some View {
        if showMirrorWidget {
            featureIcon("camera.viewfinder", surface: .mirror, action: onMirrorTap)
        }
    }

    private var leftWing: some View {
        HStack(spacing: Design.Sizes.featureIconSpacing) {
            MediaSlot(
                showSpotifyStatus: showSpotifyStatus,
                isActive: activeSurface == .spotify,
                isPlaying: spotifyIsPlaying,
                isResultState: state == .result,
                artworkData: spotifyArtworkData,
                iconStyle: compactMediaIconStyle,
                onTap: onMediaTap
            )

            if isExpanded {
                leftFeatureIcons
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .frame(width: wingWidth, alignment: .leading)
    }

    private var rightWing: some View {
        HStack(spacing: Design.Sizes.featureIconSpacing) {
            if isExpanded {
                rightFeatureIcons
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            StateIndicator(
                state: state,
                isActive: activeSurface == .agent,
                action: onAgentTap
            )
        }
        .frame(width: wingWidth, alignment: .trailing)
    }

    private var wingWidth: CGFloat {
        isExpanded ? Design.Sizes.expandedWingWidth : Design.Sizes.compactWingWidth
    }

    private func featureIcon(
        _ symbolName: String,
        surface: NotchSurface,
        action: @escaping () -> Void
    ) -> some View {
        let isActive = activeSurface == surface
        return Image(systemName: symbolName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isActive ? Design.Colors.mirrorCyan : Design.Colors.surfaceSecondary)
            .frame(
                width: Design.Sizes.featureIconSize,
                height: Design.Sizes.featureIconSize
            )
            .background(
                isActive ? Design.Colors.controlBackgroundActive : Color.clear,
                in: RoundedRectangle(cornerRadius: Design.Radii.iconSquircle, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: Design.Radii.iconSquircle, style: .continuous))
            .onTapGesture(perform: action)
    }

    // MARK: - Camera Space

    private var cameraSpace: some View {
        Capsule()
            .fill(.black)
            .frame(
                width: isExpanded
                    ? Design.Sizes.expandedCameraSpaceWidth
                    : Design.Sizes.compactCameraSpaceWidth,
                height: Design.Sizes.cameraSpaceHeight
            )
    }
}
