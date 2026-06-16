//
//  CommandCache.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Foundation

/// Caches LLM responses keyed by normalized user intent.
///
/// When the same command is spoken again, the cached result is returned
/// instantly without hitting the LLM. Entries expire after `ttl` seconds.
@MainActor
final class CommandCache {

    // MARK: - Types

    struct Entry: Codable {
        let intent: String
        let response: LLMResponse
        let command: ParsedCommand?
        let cachedAt: Date
        var hitCount: Int
    }

    // MARK: - Configuration

    private let maxEntries = 200
    private let ttl: TimeInterval = 24 * 60 * 60  // 24 hours
    private let storageKey = "notchagent.command_cache"

    // MARK: - Storage

    private var entries: [String: Entry] = [:]

    init() {
        load()
    }

    // MARK: - Public API

    /// Look up a cached response for the given intent.
    func lookup(_ intent: String) -> Entry? {
        let key = normalize(intent)
        guard var entry = entries[key] else { return nil }

        // Check TTL
        if Date().timeIntervalSince(entry.cachedAt) > ttl {
            entries.removeValue(forKey: key)
            save()
            return nil
        }

        entry.hitCount += 1
        entries[key] = entry
        save()
        return entry
    }

    /// Store a new intent → response mapping.
    func store(intent: String, response: LLMResponse, command: ParsedCommand?) {
        let key = normalize(intent)
        let entry = Entry(
            intent: intent,
            response: response,
            command: command,
            cachedAt: Date(),
            hitCount: 0
        )

        entries[key] = entry
        evictIfNeeded()
        save()
    }

    /// Remove all cached entries.
    func clear() {
        entries.removeAll()
        save()
    }

    /// Number of active cache entries.
    var count: Int { entries.count }

    // MARK: - Normalization

    /// Normalize the intent string for cache key comparison.
    ///
    /// Lowercases, trims whitespace, and collapses multiple spaces.
    private func normalize(_ intent: String) -> String {
        intent
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Eviction

    private func evictIfNeeded() {
        guard entries.count > maxEntries else { return }

        // Remove oldest entries first
        let sorted = entries.sorted { $0.value.cachedAt < $1.value.cachedAt }
        let toRemove = entries.count - maxEntries
        for (key, _) in sorted.prefix(toRemove) {
            entries.removeValue(forKey: key)
        }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return }

        // Filter expired entries on load
        let now = Date()
        entries = decoded.filter { now.timeIntervalSince($0.value.cachedAt) <= ttl }
    }
}
