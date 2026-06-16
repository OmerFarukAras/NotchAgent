//
//  DesignTokens.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

// MARK: - Design System

enum Design {

    // MARK: - Colors

    enum Colors {
        // Notch chrome
        static let notchBackground = Color.black
        static let notchBorder = Color.white.opacity(0.11)

        // Agent state palette
        static let stateIdle = Color.white.opacity(0.88)
        static let stateListening = Color.cyan
        static let stateThinking = Color.indigo
        static let stateAction = Color.yellow
        static let stateResult = Color.green
        static let stateError = Color.red
        static let stateConfirmation = Color.orange

        // Surface text
        static let surfaceLabel = Color.white
        static let surfaceSublabel = Color.white.opacity(0.58)
        static let surfaceSecondary = Color.white.opacity(0.74)
        static let surfaceControl = Color.white.opacity(0.82)
        static let surfaceMuted = Color.white.opacity(0.45)

        // Surface controls
        static let controlBackground = Color.white.opacity(0.09)
        static let controlBackgroundActive = Color.white.opacity(0.16)

        // Media accents
        static let spotifyGreen = Color.green
        static let mirrorCyan = Color.cyan

        // Progress bar
        static let progressTrack = Color.white.opacity(0.16)
        static let progressFill = Color.green

        static func stateColor(for state: NotchState) -> Color {
            switch state {
            case .idle: stateIdle
            case .listening: stateListening
            case .thinking: stateThinking
            case .action: stateAction
            case .result: stateResult
            case .error: stateError
            case .confirmation: stateConfirmation
            }
        }
    }

    // MARK: - Typography

    enum Typography {
        static let compactIcon = Font.system(size: 14, weight: .bold)
        static let expandedIcon = Font.system(size: 15, weight: .bold)
        static let compactLabel = Font.system(size: 12, weight: .semibold)
        static let surfaceTitle = Font.system(size: 13, weight: .bold)
        static let surfaceSubtitle = Font.system(size: 11, weight: .medium)
        static let surfaceControls = Font.system(size: 11, weight: .bold)
        static let surfaceCaption = Font.system(size: 10, weight: .semibold)
        static let statusLabel = Font.system(size: 11, weight: .medium)
        static let albumArtIcon = Font.system(size: 18, weight: .bold)
        static let cameraIcon = Font.system(size: 16, weight: .bold)
        static let surfaceButtonIcon = Font.system(size: 12, weight: .bold)
    }

    // MARK: - Spacing

    enum Spacing {
        static let compactHorizontal: CGFloat = 10
        static let expandedHorizontal: CGFloat = 10
        static let compactTop: CGFloat = 6
        static let expandedTop: CGFloat = 10
        static let surfaceTop: CGFloat = 7
        static let compactBottom: CGFloat = 6
        static let expandedBottom: CGFloat = 12
        static let surfaceBottom: CGFloat = 10
        static let surfaceInternalPadding: CGFloat = 8
        static let compactVerticalSpacing: CGFloat = 0
        static let expandedVerticalSpacing: CGFloat = 8
        static let surfaceVerticalSpacing: CGFloat = 5
        static let controlSpacing: CGFloat = 8
        static let albumInfoSpacing: CGFloat = 4
        static let slotIconSpacing: CGFloat = 7
    }

    // MARK: - Sizes

    enum Sizes {
        // Notch
        static let compactWidth: CGFloat = 240
        static let expandedWidth: CGFloat = 360
        static let detailedWidth: CGFloat = 390
        static let compactHeight: CGFloat = 35
        static let compactBarHeight: CGFloat = 22

        // Window
        static let windowWidth: CGFloat = 520
        static let windowHeight: CGFloat = 420
        static let screenEdgeOverlap: CGFloat = 3

        // Camera notch space
        static let compactCameraSpaceWidth: CGFloat = 124
        static let expandedCameraSpaceWidth: CGFloat = 136
        static let cameraSpaceHeight: CGFloat = 22

        // Slots
        static let compactSlotWidth: CGFloat = 22
        static let compactWingWidth: CGFloat = 44
        static let expandedWingWidth: CGFloat = 96

        // Feature icons (mirror, calendar, weather in top bar)
        static let featureIconSize: CGFloat = 22
        static let featureIconSpacing: CGFloat = 6

        // Album art
        static let albumArtSize: CGFloat = 52
        static let albumArtCornerRadius: CGFloat = 9

        // Camera preview
        static let cameraPreviewWidth: CGFloat = 360
        static let cameraPreviewHeight: CGFloat = 200
        static let mirrorCompactPreviewHeight: CGFloat = 68
        static let cameraPreviewCornerRadius: CGFloat = 12

        // Controls
        static let iconButtonSize: CGFloat = 28
        static let statusDotSize: CGFloat = 5
        static let progressWidth: CGFloat = 58
        static let progressHeight: CGFloat = 4
        static let progressFillWidth: CGFloat = 36

        // Surface content heights
        static let spotifyContentHeight: CGFloat = 74
        static let mirrorContentHeight: CGFloat = 74
        static let calendarContentHeight: CGFloat = 80
        static let weatherContentHeight: CGFloat = 54
        static let spotifyDetailedContentHeight: CGFloat = 260
        static let mirrorDetailedContentHeight: CGFloat = 260
        static let calendarDetailedContentHeight: CGFloat = 198
        static let weatherDetailedContentHeight: CGFloat = 132
        static let agentContentHeight: CGFloat = 72
        static let agentDetailedContentHeight: CGFloat = 260
        static let surfaceRowHeight: CGFloat = 52
        static let mirrorRowHeight: CGFloat = 72
    }

    // MARK: - Corner Radii

    enum Radii {
        static let notchTop: CGFloat = 2
        static let notchBottomCompact: CGFloat = 12
        static let notchBottomExpanded: CGFloat = 24
        static let settingsGroup: CGFloat = 8
        static let iconSquircle: CGFloat = 6
    }

    // MARK: - Shadows

    enum Shadows {
        static let compactRadius: CGFloat = 10
        static let compactY: CGFloat = 5
        static let compactOpacity: Double = 0.20

        static let expandedRadius: CGFloat = 18
        static let expandedY: CGFloat = 10
        static let expandedOpacity: Double = 0.30

        static let albumGlowRadius: CGFloat = 14
        static let albumGlowY: CGFloat = 6
        static let albumGlowOpacity: Double = 0.28
    }
}
