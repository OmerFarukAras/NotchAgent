//
//  AgentSurface.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Local-first agent control surface for the right-side AI indicator.
struct AgentSurface: View {
    let isExpanded: Bool
    let state: NotchState
    let message: String
    let routerMode: String
    let inputLevel: Double
    let transcript: String
    let cacheHit: Bool
    let onTap: () -> Void
    let onListen: () -> Void
    let onThink: () -> Void
    let onRun: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                stateBadge

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(state.title)
                            .font(Design.Typography.surfaceTitle)
                            .foregroundStyle(Design.Colors.surfaceLabel)
                            .lineLimit(1)

                        if cacheHit {
                            Text("⚡")
                                .font(.system(size: 10))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    Design.Colors.stateAction.opacity(0.25),
                                    in: Capsule()
                                )
                        }
                    }

                    // Compact view shows 1-2 lines
                    if !isExpanded {
                        if !transcript.isEmpty {
                            Text(transcript)
                                .font(Design.Typography.surfaceSubtitle)
                                .foregroundStyle(Design.Colors.surfaceSecondary)
                                .lineLimit(2)
                                .animation(.easeOut(duration: 0.15), value: transcript)
                        } else {
                            Text(message)
                                .font(Design.Typography.surfaceSubtitle)
                                .foregroundStyle(Design.Colors.surfaceSublabel)
                                .lineLimit(1)
                        }
                    }

                    Text(routerMode)
                        .font(Design.Typography.surfaceCaption)
                        .foregroundStyle(Design.Colors.surfaceMuted)
                        .lineLimit(1)

                    if state == .listening && !isExpanded {
                        ListeningMeter(inputLevel: inputLevel)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 8)

                if !isExpanded {
                    controls
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            // Expanded view
            if isExpanded {
                Divider()
                    .opacity(0.5)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !transcript.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Transcript")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Design.Colors.surfaceMuted)
                                
                                Text(transcript)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Design.Colors.surfaceSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if !message.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Response")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Design.Colors.surfaceMuted)

                                Text(message)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Design.Colors.surfaceLabel)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if state == .listening {
                            HStack {
                                Spacer()
                                ListeningMeter(inputLevel: inputLevel)
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }

                controls
            }
        }
        .padding(.horizontal, Design.Spacing.surfaceInternalPadding)
        .padding(.vertical, 12)
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
