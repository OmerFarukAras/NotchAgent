//
//  NotchAgentApp.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var coordinator: AppCoordinator? {
        didSet {
            guard pendingListenRequest else { return }
            pendingListenRequest = false
            coordinator?.activateAgentListening()
        }
    }

    private var pendingListenRequest = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleGetURLEvent(event:withReplyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc func handleGetURLEvent(event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
           shouldOpenListening(for: urlString) {
            if let coordinator {
                coordinator.activateAgentListening()
            } else {
                pendingListenRequest = true
            }
        }
    }

    private func shouldOpenListening(for urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              url.scheme?.lowercased() == "notchagent"
        else { return false }

        let command = url.host ?? url.path
        return command.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased() == "listen"
    }
}

@main
struct NotchAgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var coordinator: AppCoordinator

    init() {
        let coordinator = AppCoordinator()
        _coordinator = State(initialValue: coordinator)
        appDelegate.coordinator = coordinator
    }

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
        .windowResizability(.contentSize)
    }
}
