//
//  CommandPlan.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 17.06.2026.
//

import Foundation

/// Structured plan of commands.
struct CommandPlan: Sendable, Codable {
    var steps: [ParsedCommand]
    
    static func parse(from text: String) -> CommandPlan? {
        // 1. Try to find a JSON array
        if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"), start < end {
            let json = text[start...end]
            if let data = String(json).data(using: .utf8),
               let parsedSteps = try? JSONDecoder().decode([ParsedCommand].self, from: data) {
                return CommandPlan(steps: parsedSteps)
            }
        }
        
        // 2. Fallback to single command parsing
        if let singleCommand = ParsedCommand.parse(from: text) {
            return CommandPlan(steps: [singleCommand])
        }
        
        return nil
    }
}
