//
//  VectorMemoryService.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 19.06.2026.
//

import Foundation
import NaturalLanguage

struct MemoryFact: Codable, Identifiable {
    var id: UUID = UUID()
    let text: String
    let vector: [Double]
    let date: Date
}

actor VectorMemoryService {
    static let shared = VectorMemoryService()
    
    private var facts: [MemoryFact] = []
    private let saveURL: URL
    private let embedding: NLEmbedding?
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let notchDir = appSupport.appendingPathComponent("NotchAgent")
        try? FileManager.default.createDirectory(at: notchDir, withIntermediateDirectories: true, attributes: nil)
        self.saveURL = notchDir.appendingPathComponent("vector_memory.json")
        
        // Native Apple Embedding model for English/Turkish (NLEmbedding usually works best on English, but handles basic multilanguage)
        self.embedding = NLEmbedding.sentenceEmbedding(for: .english)
        
        load()
    }
    
    func learn(text: String) {
        guard let embedding = embedding, let vector = embedding.vector(for: text) else { return }
        
        // Ensure no exact duplicates
        if facts.contains(where: { $0.text.lowercased() == text.lowercased() }) {
            return
        }
        
        let fact = MemoryFact(text: text, vector: vector, date: Date())
        facts.append(fact)
        save()
    }
    
    func search(query: String, topK: Int = 3) -> [MemoryFact] {
        guard let embedding = embedding, let queryVector = embedding.vector(for: query), !facts.isEmpty else {
            return []
        }
        
        // Calculate cosine similarity
        let scoredFacts = facts.map { fact -> (MemoryFact, Double) in
            let score = cosineSimilarity(a: queryVector, b: fact.vector)
            return (fact, score)
        }
        
        // Sort by highest similarity
        let sorted = scoredFacts.sorted(by: { $0.1 > $1.1 })
        
        // Return topK results with a reasonable threshold (e.g. > 0.4)
        return sorted.filter { $0.1 > 0.4 }.prefix(topK).map { $0.0 }
    }
    
    func clear() {
        facts.removeAll()
        save()
    }
    
    func allFacts() -> [MemoryFact] {
        return facts.sorted(by: { $0.date > $1.date })
    }
    
    private func cosineSimilarity(a: [Double], b: [Double]) -> Double {
        guard a.count == b.count else { return 0.0 }
        var dotProduct: Double = 0.0
        var normA: Double = 0.0
        var normB: Double = 0.0
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        if normA == 0.0 || normB == 0.0 { return 0.0 }
        return dotProduct / (sqrt(normA) * sqrt(normB))
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(facts)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("Failed to save vector memory: \\(error)")
        }
    }
    
    private func load() {
        do {
            let data = try Data(contentsOf: saveURL)
            facts = try JSONDecoder().decode([MemoryFact].self, from: data)
        } catch {
            // It's normal to fail on first run
            facts = []
        }
    }
}
