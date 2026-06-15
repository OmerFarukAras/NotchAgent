//
//  SurfaceIconButton.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Small circular icon button used inside surfaces (mirror shortcut, back button, etc.).
struct SurfaceIconButton: View {
    let symbolName: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(Design.Typography.surfaceButtonIcon)
                .foregroundStyle(isActive ? Design.Colors.spotifyGreen : Design.Colors.surfaceControl)
                .frame(width: Design.Sizes.iconButtonSize, height: Design.Sizes.iconButtonSize)
        }
        .buttonStyle(.plain)
        .padding(1)
    }
}
