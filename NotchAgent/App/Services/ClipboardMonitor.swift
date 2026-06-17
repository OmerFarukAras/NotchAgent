//
//  ClipboardMonitor.swift
//  NotchAgent
//
//  Created by NotchAgent.
//

import AppKit

@MainActor
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
        self.lastChangeCount = NSPasteboard.general.changeCount
        
        // Initial fetch
        updateClipboardText()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForChanges()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkForChanges() {
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            updateClipboardText()
        }
    }

    private func updateClipboardText() {
        if let text = NSPasteboard.general.string(forType: .string) {
            // Limit clipboard text length to avoid token explosion
            let maxLength = 4000
            if text.count > maxLength {
                appState?.currentClipboardText = String(text.prefix(maxLength)) + "\n...[truncated]"
            } else {
                appState?.currentClipboardText = text
            }
        } else {
            appState?.currentClipboardText = nil
        }
    }
}
