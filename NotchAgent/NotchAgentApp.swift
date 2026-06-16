//
//  NotchAgentApp.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleGetURLEvent(event:withReplyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
           let url = URL(string: urlString), url.host == "listen" {
            coordinator?.activateAgentListening()
        }
    }
}

@main
struct NotchAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("NotchAgent", systemImage: "sparkles") {
            Button("Run Demo Flow") {
                coordinator.notchViewModel.runDemoFlow()
            }
            .onAppear {
                appDelegate.coordinator = coordinator
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
        .windowResizability(.contentSize)
    }
}
