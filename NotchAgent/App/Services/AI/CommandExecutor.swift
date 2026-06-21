//
//  CommandExecutor.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 19.06.2026.
//

import AppKit
import Foundation
import UserNotifications

@MainActor
final class CommandExecutor {
    
    var onPhaseChange: ((AgentPhase, String) -> Void)?
    var onMusicControl: ((String) -> Void)?
    var onMusicSearch: ((String) -> Void)?
    var onSettingChange: ((String, String) -> Void)?
    var onPendingCommand: ((ParsedCommand) -> Void)?
    var onBackgroundResearchSummarize: ((String, String) async throws -> String)?
    
    var pendingCommand: ParsedCommand?
    
    func executeCommandPlan(_ plan: CommandPlan) {
        Task { @MainActor in
            for command in plan.steps {
                let success = executeSingleCommand(command)
                if !success {
                    break
                }
                if command.needs_confirmation == true || command.action == "ask_clarification" {
                    break
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    private func executeSingleCommand(_ command: ParsedCommand) -> Bool {
        let summary = command.summary ?? "Done"
        setPhase(.executing, message: "Running: \(summary)")

        if command.action == "ask_clarification" {
            setPhase(.done, message: summary)
            return true
        }

        if command.needs_confirmation == true {
            pendingCommand = command
            onPendingCommand?(command)
            setPhase(.done, message: summary)
            return true
        }

        if command.action == "open_url", let urlString = command.target, let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)") {
            NSWorkspace.shared.open(url)
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        if command.action == "open_urls",
           let browserName = command.target,
           let script = command.script {
            let urls = script
                .components(separatedBy: .newlines)
                .compactMap { normalizedURLString(from: $0) }

            guard !urls.isEmpty else {
                setPhase(.error, message: "No URLs to open")
                return false
            }

            openURLs(urls, inBrowser: browserName)
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        if command.action == "music_control" {
            onMusicControl?(command.target ?? "playpause")
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        if command.action == "search_music" {
            let query = command.target ?? ""
            onMusicSearch?(query)
            
            // Implicit memory: save the song they asked to play with temporal context
            let dateString = Date().formatted(date: .abbreviated, time: .shortened)
            Task {
                await VectorMemoryService.shared.learn(text: "User requested to play music: '\(query)' on \(dateString).")
            }
            
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        if command.action == "change_setting", let setting = command.target, let value = command.script {
            onSettingChange?(setting, value)
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        if command.action == "type_text", let text = command.script {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            let source = """
            tell application "System Events"
                keystroke "v" using command down
            end tell
            """
            
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            
            if error != nil {
                setPhase(.error, message: "Needs Accessibility Permission")
                return false
            } else {
                setPhase(.done, message: "✓ Typed Text")
                return true
            }
        }
        
        if command.action == "ui_interaction", let script = command.script {
            // New action for interacting with UI elements via AppleScript
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            
            if error != nil {
                setPhase(.error, message: "UI Interaction failed. Needs Accessibility Permission.")
                return false
            } else {
                setPhase(.done, message: "✓ \(summary)")
                return true
            }
        }
        
        if command.action == "background_research", let query = command.target {
            // Fire and forget background research
            Task {
                await performBackgroundResearch(query: query)
            }
            setPhase(.done, message: "Araştırma başlatıldı...")
            return true
        }
        
        if command.action == "show_ghost_cursor", let coords = command.target {
            showGhostCursor(at: coords, message: summary)
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        if command.action == "memorize", let fact = command.target {
            Task {
                await VectorMemoryService.shared.learn(text: fact)
            }
            setPhase(.done, message: "✓ Öğrenildi: \(fact)")
            return true
        }

        if command.action == "open_app", let appName = command.target {
            let success = NSWorkspace.shared.launchApplication(appName)
            if success {
                setPhase(.done, message: "✓ \(summary)")
                return true
            } else {
                setPhase(.error, message: "Could not open \(appName)")
                return false
            }
        }
        
        guard let script = command.script, !script.isEmpty else {
            setPhase(.done, message: summary)
            return true
        }

        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)

        if error != nil {
            setPhase(.error, message: "Script execution failed")
            return false
        } else {
            setPhase(.done, message: "✓ \(summary)")
            return true
        }
    }
    
    private func setPhase(_ phase: AgentPhase, message: String) {
        onPhaseChange?(phase, message)
    }
    
    private func normalizedURLString(from rawValue: String) -> String? {
        let token = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard !token.isEmpty else { return nil }

        let aliases: [String: String] = [
            "youtube": "https://youtube.com",
            "you tube": "https://youtube.com",
            "github": "https://github.com",
            "git hub": "https://github.com",
            "google": "https://google.com",
            "gmail": "https://mail.google.com",
            "chatgpt": "https://chatgpt.com",
            "chat gpt": "https://chatgpt.com",
            "x": "https://x.com",
            "twitter": "https://x.com",
            "reddit": "https://reddit.com"
        ]

        if let alias = aliases[token] {
            return alias
        }

        if token.hasPrefix("http://") || token.hasPrefix("https://") {
            return token
        }

        if token.contains(".") && !token.contains(" ") {
            return "https://\(token)"
        }

        return nil
    }

    private func openURLs(_ urls: [String], inBrowser browserName: String) {
        let escapedBrowser = browserName.replacingOccurrences(of: "\"", with: "\\\\\"")
        let lines = urls.map { urlString in
            let escapedURL = urlString.replacingOccurrences(of: "\"", with: "\\\\\"")
            return "open location \"\(escapedURL)\""
        }.joined(separator: "\n    ")

        let source = """
        tell application "\(escapedBrowser)"
            activate
            \(lines)
        end tell
        """

        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
    }
    
    // MARK: - New Advanced Capabilities
    
    private func performBackgroundResearch(query: String) async {
        do {
            let results = try await WebSearchService.performSearch(query: query)
            
            var bodyText = results
            if let summarizer = onBackgroundResearchSummarize {
                if let summary = try? await summarizer(query, results) {
                    bodyText = summary
                }
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Araştırma Tamamlandı: \(query)"
            content.body = bodyText
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
            
            await MainActor.run {
                self.setPhase(.done, message: "Araştırma bitti: \(query)")
            }
        } catch {
            await MainActor.run {
                self.setPhase(.error, message: "Araştırma hatası")
            }
        }
    }
    
    private func showGhostCursor(at coordinates: String, message: String) {
        // coordinates usually looks like "100,200"
        let parts = coordinates.split(separator: ",")
        guard parts.count == 2, 
              let x = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)), 
              let y = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        
        GhostCursorManager.shared.show(at: CGPoint(x: x, y: y), message: message)
    }
}
