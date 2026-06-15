//
//  NotchAgentApp.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

@main
struct NotchAgentApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("NotchAgent", systemImage: "sparkles") {
            Button("Run Demo Flow") {
                coordinator.notchViewModel.runDemoFlow()
            }

            if coordinator.appState.isUpdateAvailable {
                Button("Update Available") {
                    coordinator.openLatestRelease()
                }
            }

            Divider()

            Button("Settings") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",")

            Button("Quit NotchAgent") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
                .environment(coordinator.appState)
                .environment(coordinator)
        }
    }
}
