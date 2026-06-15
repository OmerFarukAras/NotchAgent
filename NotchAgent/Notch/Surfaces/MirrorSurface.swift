//
//  MirrorSurface.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

/// Camera / mirror preview surface.
struct MirrorSurface: View {
    let isExpanded: Bool
    let selectedCameraID: String

    var body: some View {
        if isExpanded {
            expandedBody
        } else {
            compactBody
        }
    }

    private var compactBody: some View {
        HStack(spacing: 14) {
            header(alignment: .leading)

            Spacer(minLength: 4)

            cameraPreview(height: Design.Sizes.mirrorCompactPreviewHeight)
                .frame(width: 100)
        }
        .padding(.horizontal, Design.Spacing.surfaceInternalPadding)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(alignment: .horizontal)
            cameraPreview(height: Design.Sizes.cameraPreviewHeight)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Design.Spacing.surfaceInternalPadding)
    }

    private enum HeaderAlignment {
        case leading
        case horizontal
    }

    @ViewBuilder
    private func header(alignment: HeaderAlignment) -> some View {
        let title = HStack(spacing: 7) {
            Text("Mirror")
                .font(Design.Typography.surfaceTitle)
                .foregroundStyle(Design.Colors.surfaceLabel)

            Image(systemName: "camera.viewfinder")
                .font(Design.Typography.surfaceControls)
                .foregroundStyle(Design.Colors.mirrorCyan)
        }

        if alignment == .horizontal {
            HStack(spacing: 10) {
                title
                Spacer()
                statusText
            }
        } else {
            VStack(alignment: .leading, spacing: Design.Spacing.albumInfoSpacing) {
                title
                statusText
            }
            .frame(height: Design.Sizes.mirrorRowHeight, alignment: .center)
        }
    }

    private var statusText: some View {
        HStack(spacing: 8) {
            Text("Live camera")
                .font(Design.Typography.surfaceSubtitle)
                .foregroundStyle(Design.Colors.surfaceSublabel)

            Text("Mirrored")
                .font(Design.Typography.surfaceCaption)
                .foregroundStyle(Design.Colors.surfaceMuted)
        }
    }

    private func cameraPreview(height: CGFloat) -> some View {
        CameraPreviewView(selectedCameraID: selectedCameraID)
            .frame(height: height)
            .clipShape(RoundedRectangle(
                cornerRadius: Design.Sizes.cameraPreviewCornerRadius,
                style: .continuous
            ))
            .overlay {
                RoundedRectangle(cornerRadius: Design.Sizes.cameraPreviewCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Design.Colors.mirrorCyan)
                    .frame(width: Design.Sizes.statusDotSize, height: Design.Sizes.statusDotSize)
                    .padding(7)
            }
    }
}
