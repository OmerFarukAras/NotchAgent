//
//  NotchAgentIntent.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 17.06.2026.
//

import AppIntents
import AppKit

struct ListenIntent: AppIntent {
    static let title: LocalizedStringResource = "Listen to NotchAgent"
    static let description = IntentDescription("Triggers the NotchAgent to start listening.")
    
    static let openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: NSNotification.Name("NotchAgentStartListening"), object: nil)
        return .result()
    }
}

struct NotchAgentShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ListenIntent(),
            phrases: [
                "Listen to \(.applicationName)",
                "Talk to \(.applicationName)",
                "Trigger \(.applicationName)",
                "Ask \(.applicationName) to listen"
            ],
            shortTitle: "Talk to NotchAgent",
            systemImageName: "waveform"
        )
    }
}
