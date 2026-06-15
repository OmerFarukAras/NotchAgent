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
