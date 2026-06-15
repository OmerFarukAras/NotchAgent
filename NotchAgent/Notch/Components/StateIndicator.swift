//
//  StateIndicator.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Agent state icon — always top-right, never shows text label.
///
/// Icon color and pulse animation change based on agent state.
/// Position and size are constant across all notch states.
struct StateIndicator: View {
    let state: NotchState
    let isActive: Bool
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            Image(systemName: state.symbolName)
                .font(Design.Typography.compactIcon)
                .foregroundStyle(Design.Colors.stateColor(for: state))
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .animation(.indicatorPulse(for: state), value: isPulsing)
                .frame(width: Design.Sizes.featureIconSize, height: Design.Sizes.featureIconSize)
                .background(
                    isActive ? Design.Colors.controlBackgroundActive : Color.clear,
                    in: RoundedRectangle(cornerRadius: Design.Radii.iconSquircle, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help(state.title)
        .onAppear { isPulsing = true }
    }

    private var pulseScale: CGFloat {
        state.isPulsing ? (isPulsing ? 1.10 : 0.92) : 1.0
    }

    private var pulseOpacity: Double {
        state.isPulsing ? (isPulsing ? 1.0 : 0.62) : 1.0
    }
}
