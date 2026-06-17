//
//  MemoryManager.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 17.06.2026.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
final class MemoryManager {
    static let shared = MemoryManager()
    
    var modelContext: ModelContext?

    private init() {
        do {
            let container = try ModelContainer(for: Fact.self, CachedCommand.self)
            self.modelContext = ModelContext(container)
        } catch {
            print("Failed to initialize SwiftData container: \(error)")
        }
    }

    func fetchRecentFacts(limit: Int = 10) -> [Fact] {
        guard let context = modelContext else { return [] }
        
        var fetchDescriptor = FetchDescriptor<Fact>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        fetchDescriptor.fetchLimit = limit
        
        do {
            return try context.fetch(fetchDescriptor)
        } catch {
            print("Error fetching facts: \(error)")
            return []
        }
    }

    func addFact(content: String, category: String = "General") {
        guard let context = modelContext else { return }
        
        let newFact = Fact(content: content, category: category)
        context.insert(newFact)
        
        do {
            try context.save()
        } catch {
            print("Error saving fact: \(error)")
        }
    }

    func clearMemory() {
        guard let context = modelContext else { return }
        
        do {
            try context.delete(model: Fact.self)
            try context.save()
        } catch {
            print("Error clearing memory: \(error)")
        }
    }

    // MARK: - Cache Methods

    func lookupCommand(intent: String) -> CachedCommand? {
        guard let context = modelContext else { return nil }
        
        let normalized = normalize(intent)
        let fetchDescriptor = FetchDescriptor<CachedCommand>(predicate: #Predicate { $0.intent == normalized })
        
        do {
            let results = try context.fetch(fetchDescriptor)
            guard let entry = results.first else { return nil }
            
            // 24 hour TTL check
            if Date().timeIntervalSince(entry.cachedAt) > 24 * 60 * 60 {
                context.delete(entry)
                try? context.save()
                return nil
            }
            
            entry.hitCount += 1
            try? context.save()
            return entry
        } catch {
            print("Error looking up cache: \(error)")
            return nil
        }
    }

    func cacheCommand(intent: String, response: LLMResponse, command: ParsedCommand?) {
        guard let context = modelContext else { return }
        
        let normalized = normalize(intent)
        
        // Remove old entry if exists
        let fetchDescriptor = FetchDescriptor<CachedCommand>(predicate: #Predicate { $0.intent == normalized })
        if let existing = try? context.fetch(fetchDescriptor).first {
            context.delete(existing)
        }
        
        // Eviction logic if over 200 items
        if getCacheCount() >= 200 {
            var allCache = FetchDescriptor<CachedCommand>(sortBy: [SortDescriptor(\.cachedAt, order: .forward)])
            if let oldest = try? context.fetch(allCache).first {
                context.delete(oldest)
            }
        }
        
        let responseJSON = (try? String(data: JSONEncoder().encode(response), encoding: .utf8)) ?? ""
        let commandJSON = command != nil ? (try? String(data: JSONEncoder().encode(command), encoding: .utf8)) : nil
        
        let newEntry = CachedCommand(intent: normalized, responseJSON: responseJSON, commandJSON: commandJSON)
        context.insert(newEntry)
        
        try? context.save()
    }

    func clearCache() {
        guard let context = modelContext else { return }
        do {
            try context.delete(model: CachedCommand.self)
            try context.save()
        } catch {
            print("Error clearing cache: \(error)")
        }
    }

    func getCacheCount() -> Int {
        guard let context = modelContext else { return 0 }
        let descriptor = FetchDescriptor<CachedCommand>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    private func normalize(_ intent: String) -> String {
        intent
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
