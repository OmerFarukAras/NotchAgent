//
//  SpotifySurface.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI
import AppKit

struct SpotifySurface: View {
    let title: String
    let artist: String
    let isPlaying: Bool
    let progress: Double
    let status: String
    let artworkData: Data?
    let volume: Double
    let isShuffling: Bool
    let isRepeating: Bool
    let isExpanded: Bool
    let onOpen: () -> Void
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onToggleShuffle: () -> Void
    let onToggleRepeat: () -> Void
    let onVolumeChange: (Double) -> Void

    var body: some View {
        if isExpanded {
            expandedBody
        } else {
            compactBody
        }
    }

    // MARK: - Compact Body

    private var compactBody: some View {
        HStack(spacing: 13) {
            albumArt(size: Design.Sizes.albumArtSize)
            trackInfo(alignment: .leading)
            Spacer(minLength: 8)
            compactPlaybackControls
        }
        .padding(.horizontal, Design.Spacing.surfaceInternalPadding)
    }

    // MARK: - Expanded Body

    private var expandedBody: some View {
        VStack(spacing: 16) {
            albumArt(size: 140)
                .padding(.top, 4)

            HStack {
                trackInfo(alignment: .leading)
                Spacer()
                expandedPlaybackControls
            }
            .padding(.horizontal, 4)

            volumeSlider
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, Design.Spacing.surfaceInternalPadding)
    }

    // MARK: - Components

    private func albumArt(size: CGFloat) -> some View {
        Group {
            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: Design.Sizes.albumArtCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.green, .cyan, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(.white.opacity(0.88))
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(cornerRadius: Design.Sizes.albumArtCornerRadius, style: .continuous)
        )
        .background {
            if let artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .blur(radius: isExpanded ? 30 : 15)
                    .opacity(isExpanded ? 0.6 : 0.4)
                    .offset(y: isExpanded ? 10 : 5)
            }
        }
    }

    private func trackInfo(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Design.Spacing.albumInfoSpacing) {
            Text(title)
                .font(Design.Typography.surfaceTitle)
                .foregroundStyle(Design.Colors.surfaceLabel)
                .lineLimit(1)
                .contentTransition(.opacity)
                .id(title)

            Text(artist)
                .font(Design.Typography.surfaceSubtitle)
                .foregroundStyle(Design.Colors.surfaceSublabel)
                .lineLimit(1)
                .contentTransition(.opacity)
                .id(artist)
        }
    }

    private var compactPlaybackControls: some View {
        HStack(spacing: Design.Spacing.controlSpacing) {
            SurfaceIconButton(symbolName: "arrow.up.forward.app", isActive: false, action: onOpen)
            SurfaceIconButton(symbolName: "backward.fill", isActive: false, action: onPrevious)
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isPlaying ? Design.Colors.spotifyGreen : Design.Colors.surfaceControl)
                    .frame(width: Design.Sizes.iconButtonSize, height: Design.Sizes.iconButtonSize)
            }
            .buttonStyle(.plain)
            SurfaceIconButton(symbolName: "forward.fill", isActive: false, action: onNext)
        }
    }

    private var expandedPlaybackControls: some View {
        HStack(spacing: Design.Spacing.controlSpacing) {
            SurfaceIconButton(symbolName: "shuffle", isActive: isShuffling, action: onToggleShuffle)
            SurfaceIconButton(symbolName: "backward.fill", isActive: false, action: onPrevious)
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isPlaying ? Design.Colors.spotifyGreen : Design.Colors.surfaceControl)
                    .frame(width: Design.Sizes.iconButtonSize, height: Design.Sizes.iconButtonSize)
            }
            .buttonStyle(.plain)
            SurfaceIconButton(symbolName: "forward.fill", isActive: false, action: onNext)
            SurfaceIconButton(symbolName: "repeat", isActive: isRepeating, action: onToggleRepeat)
        }
    }

    private var volumeSlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(Design.Colors.surfaceMuted)
                .font(.system(size: 10))

            Slider(
                value: Binding(
                    get: { volume },
                    set: { onVolumeChange($0) }
                ),
                in: 0...1
            )
            .tint(Design.Colors.spotifyGreen)

            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(Design.Colors.surfaceMuted)
                .font(.system(size: 10))
        }
    }
}
