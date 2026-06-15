//
//  AgentSurface.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Local-first agent control surface for the right-side AI indicator.
struct AgentSurface: View {
    let state: NotchState
    let message: String
    let routerMode: String
    let inputLevel: Double
    let onListen: () -> Void
    let onThink: () -> Void
    let onRun: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            stateBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                    .font(Design.Typography.surfaceTitle)
                    .foregroundStyle(Design.Colors.surfaceLabel)
                    .lineLimit(1)

                Text(message)
                    .font(Design.Typography.surfaceSubtitle)
                    .foregroundStyle(Design.Colors.surfaceSublabel)
                    .lineLimit(1)

                Text(routerMode)
                    .font(Design.Typography.surfaceCaption)
                    .foregroundStyle(Design.Colors.surfaceMuted)
                    .lineLimit(1)

                if state == .listening {
                    ListeningMeter(inputLevel: inputLevel)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 8)

            controls
        }
        .padding(.horizontal, Design.Spacing.surfaceInternalPadding)
    }

    private var stateBadge: some View {
        Image(systemName: state.symbolName)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Design.Colors.stateColor(for: state))
            .frame(width: 40, height: 40)
            .background(Design.Colors.controlBackgroundActive, in: Circle())
    }

    private var controls: some View {
        HStack(spacing: 8) {
            SurfaceIconButton(symbolName: "waveform", isActive: state == .listening, action: onListen)
            SurfaceIconButton(symbolName: "brain.head.profile", isActive: state == .thinking, action: onThink)
            SurfaceIconButton(symbolName: "play.fill", isActive: state == .action, action: onRun)
            SurfaceIconButton(symbolName: "arrow.counterclockwise", isActive: false, action: onReset)
        }
    }
}

private struct ListeningMeter: View {
    let inputLevel: Double

    private let barHeights: [CGFloat] = [0.34, 0.62, 0.92, 0.48, 0.76, 0.38, 0.84, 0.56]

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let normalizedLevel = max(0.05, min(inputLevel, 1.0))

            HStack(alignment: .center, spacing: 3) {
                ForEach(barHeights.indices, id: \.self) { index in
                    let phase = time * 4.2 + Double(index) * 0.72
                    let wave = (sin(phase) + 1) / 2
                    let responsiveWave = 0.18 + (wave * normalizedLevel)
                    let height = 4 + (barHeights[index] * 14 * responsiveWave)

                    Capsule(style: .continuous)
                        .fill(Design.Colors.stateColor(for: .listening).opacity(0.28 + normalizedLevel * 0.62))
                        .frame(width: 3, height: height)
                }
            }
            .frame(width: 46, height: 18, alignment: .center)
        }
        .accessibilityLabel("Listening activity")
    }
}
