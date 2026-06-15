//
//  GlowModifier.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

// MARK: - Notch Glow Effect

/// Adds a soft, colored glow behind a view — used for album-art accent
/// and agent-state feedback on the notch body.
struct NotchGlowModifier: ViewModifier {
    let color: Color
    let intensity: Double
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: Design.Radii.notchBottomExpanded, style: .continuous)
                        .fill(color.opacity(0.08 * intensity))
                        .blur(radius: 20)
                        .offset(y: 4)
                }
            }
            .shadow(
                color: isActive ? color.opacity(0.15 * intensity) : .clear,
                radius: isActive ? 24 : 0,
                y: isActive ? 8 : 0
            )
            .animation(.easeInOut(duration: 0.6), value: isActive)
            .animation(.easeInOut(duration: 0.6), value: color.description)
    }
}

extension View {
    /// Premium glow effect that adapts to album art or agent state color.
    func notchGlow(color: Color, intensity: Double = 1.0, isActive: Bool = true) -> some View {
        modifier(NotchGlowModifier(color: color, intensity: intensity, isActive: isActive))
    }
}
