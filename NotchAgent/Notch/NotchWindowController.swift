//
//  NotchWindowController.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import AppKit
import QuartzCore
import SwiftUI

/// Manages the borderless NSPanel that hosts the notch overlay.
@MainActor
final class NotchWindowController {
    private let appState: AppState
    private let viewModel: NotchViewModel
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?
    private var outsideClickMonitor: Any?

    init(appState: AppState, viewModel: NotchViewModel) {
        self.appState = appState
        self.viewModel = viewModel

        let panelSize = viewModel.windowSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel = panel

        let rootView = NotchView(
            viewModel: viewModel,
            onHideNotch: { [weak appState, weak viewModel, weak panel] in
                appState?.isNotchVisible = false
                viewModel?.closeSurface()
                panel?.orderOut(nil)
            }
        )
        .environment(appState)

        panel.contentView = NSHostingView(rootView: rootView)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false

        installOutsideClickMonitor()
    }

    deinit {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
    }

    // MARK: - Visibility

    func show() {
        hideTask?.cancel()
        panel.alphaValue = panel.isVisible ? panel.alphaValue : 0
        positionPanel()
        panel.orderFrontRegardless()
        NSApp.setActivationPolicy(.accessory)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.windowShowDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        hideTask?.cancel()
        viewModel.closeSurface()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.windowHideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }

        hideTask = Task { [weak panel] in
            try? await Task.sleep(for: Motion.windowHideDelay)
            panel?.orderOut(nil)
        }
    }

    // MARK: - Positioning

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let size = viewModel.windowSize
        let x = screenFrame.midX - size.width / 2
        let topLeft = NSPoint(
            x: x,
            y: screenFrame.maxY + Design.Sizes.screenEdgeOverlap
        )

        panel.setContentSize(size)
        panel.setFrameTopLeftPoint(topLeft)
    }

    // MARK: - Outside Click

    private func installOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.viewModel.handleOutsideClick()
            }
        }
    }
}
