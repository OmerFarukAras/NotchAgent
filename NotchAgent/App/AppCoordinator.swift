//
//  AppCoordinator.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Carbon
import AppKit
import Foundation
import ServiceManagement

/// Top-level coordinator — owns AppState, NotchViewModel, and the window controller.
@MainActor @Observable
final class AppCoordinator {
    let appState: AppState
    let notchViewModel: NotchViewModel

    private let notchWindowController: NotchWindowController
    private var shortcutRef: EventHotKeyRef?
    private var shortcutEventHandler: EventHandlerRef?

    init() {
        let appState = AppState()
        let viewModel = NotchViewModel(appState: appState)
        self.appState = appState
        self.notchViewModel = viewModel
        self.notchWindowController = NotchWindowController(
            appState: appState,
            viewModel: viewModel
        )

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.appState.isNotchVisible else { return }
            self.notchWindowController.show()
        }

        configureGlobalShortcut(appState.defaultShortcut)
        refreshLoginItemStatus()
        checkForUpdatesIfNeeded()
    }

    func toggleNotchVisibility() {
        setNotchVisibility(!appState.isNotchVisible)
    }

    func setNotchVisibility(_ isVisible: Bool) {
        appState.isNotchVisible = isVisible
        if isVisible {
            notchWindowController.show()
        } else {
            notchWindowController.hide()
        }
    }

    func setOpenAtLogin(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            appState.openAtLogin = isEnabled
            appState.startupStatusMessage = isEnabled ? "Enabled" : "Disabled"
        } catch {
            appState.openAtLogin = SMAppService.mainApp.status == .enabled
            appState.startupStatusMessage = "Could not update login item"
        }
    }

    func setDefaultShortcut(_ shortcut: String) {
        appState.defaultShortcut = shortcut
        configureGlobalShortcut(shortcut)
    }

    func checkForUpdates(force: Bool = false) {
        guard !appState.updateCheckInProgress else { return }

        appState.updateCheckInProgress = true
        appState.updateStatusMessage = force ? "Checking for updates..." : appState.updateStatusMessage

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let result = try await UpdateChecker.checkForUpdates()
                self.appState.lastUpdateCheckDate = Date()
                self.appState.availableVersion = result.latestVersion
                self.appState.updateReleaseURL = result.releaseURL
                self.appState.isUpdateAvailable = result.isUpdateAvailable
                self.appState.updateStatusMessage = result.isUpdateAvailable
                    ? "Version \(result.latestVersion) is available"
                    : "NotchAgent is up to date"
            } catch {
                self.appState.updateStatusMessage = "Could not check for updates"
            }

            self.appState.updateCheckInProgress = false
        }
    }

    func openLatestRelease() {
        guard let url = appState.updateReleaseURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func checkForUpdatesIfNeeded() {
        let now = Date()
        if let lastCheck = appState.lastUpdateCheckDate,
           now.timeIntervalSince(lastCheck) < 24 * 60 * 60 {
            return
        }

        checkForUpdates()
    }

    private func refreshLoginItemStatus() {
        let isEnabled = SMAppService.mainApp.status == .enabled
        appState.openAtLogin = isEnabled
        appState.startupStatusMessage = isEnabled ? "Enabled" : "Disabled"
    }

    private func configureGlobalShortcut(_ shortcut: String) {
        unregisterShortcut()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }

                let coordinator = Unmanaged<AppCoordinator>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                Task { @MainActor in
                    coordinator.toggleNotchVisibility()
                }

                return noErr
            },
            1,
            &eventType,
            userData,
            &shortcutEventHandler
        )

        let hotKeyID = EventHotKeyID(signature: 0x4E544348, id: 1)
        let status = RegisterEventHotKey(
            49,
            carbonModifiers(for: shortcut),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &shortcutRef
        )

        appState.shortcutStatusMessage = status == noErr
            ? "\(shortcut) active"
            : "Shortcut unavailable"
    }

    private func unregisterShortcut() {
        if let shortcutRef {
            UnregisterEventHotKey(shortcutRef)
            self.shortcutRef = nil
        }

        if let shortcutEventHandler {
            RemoveEventHandler(shortcutEventHandler)
            self.shortcutEventHandler = nil
        }
    }

    private func carbonModifiers(for shortcut: String) -> UInt32 {
        switch shortcut {
        case "Command + Space":
            UInt32(cmdKey)
        case "Control + Space":
            UInt32(controlKey)
        default:
            UInt32(optionKey)
        }
    }
}
