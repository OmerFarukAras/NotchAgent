//
//  MediaSlot.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Left side of the compact bar — just the music icon, no text.
///
/// Position and size never change between compact/expanded states.
struct MediaSlot: View {
    let showSpotifyStatus: Bool
    let isActive: Bool
    let isPlaying: Bool
    let isResultState: Bool
    let artworkData: Data?
    let iconStyle: String
    let onTap: () -> Void

    var body: some View {
        Group {
            if showSpotifyStatus {
                if iconStyle == "Album Art" {
                    albumArtIcon
                        .symbolEffect(.bounce, value: isResultState)
                } else if iconStyle == "Music Note" {
                    Image(systemName: "music.note")
                        .font(Design.Typography.compactIcon)
                        .foregroundStyle(isActive ? Design.Colors.spotifyGreen : Design.Colors.surfaceSecondary)
                        .symbolEffect(.bounce, value: isResultState)
                } else {
                    if isPlaying {
                        EqualizerIndicator(isActive: isActive)
                            .symbolEffect(.bounce, value: isResultState)
                    } else {
                        Image(systemName: "music.note")
                            .font(Design.Typography.compactIcon)
                            .foregroundStyle(isActive ? Design.Colors.spotifyGreen : Design.Colors.surfaceSecondary)
                            .symbolEffect(.bounce, value: isResultState)
                    }
                }
            }
        }
        .frame(
            width: Design.Sizes.compactSlotWidth,
            height: Design.Sizes.featureIconSize,
            alignment: .center
        )
        .contentShape(RoundedRectangle(cornerRadius: Design.Radii.iconSquircle, style: .continuous))
        .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var albumArtIcon: some View {
        if let artworkData, let image = NSImage(data: artworkData) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 15, height: 15)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Image(systemName: "music.note")
                .font(Design.Typography.compactIcon)
                .foregroundStyle(isActive ? Design.Colors.spotifyGreen : Design.Colors.surfaceSecondary)
        }
    }
}

struct EqualizerIndicator: View {
    let isActive: Bool
    @State private var animationPhase = false
    
    var body: some View {
        HStack(spacing: 2.5) {
            bar(height: animationPhase ? 11 : 4, delay: 0.0)
            bar(height: animationPhase ? 5 : 13, delay: 0.2)
            bar(height: animationPhase ? 14 : 6, delay: 0.1)
            bar(height: animationPhase ? 6 : 12, delay: 0.3)
            bar(height: animationPhase ? 12 : 5, delay: 0.15)
        }
        .frame(height: 14, alignment: .center)
        .foregroundStyle(isActive ? Design.Colors.spotifyGreen : Design.Colors.surfaceSecondary)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animationPhase = true
            }
        }
    }
    
    private func bar(height: CGFloat, delay: Double) -> some View {
        Capsule()
            .frame(width: 3, height: height)
            .animation(
                .easeInOut(duration: 0.35)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: animationPhase
            )
    }
}
