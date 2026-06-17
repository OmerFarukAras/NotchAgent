//
//  Fact.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 17.06.2026.
//

import Foundation
import SwiftData

@Model
final class Fact {
    var id: UUID
    var content: String
    var category: String
    var confidence: Double
    var createdAt: Date

    init(id: UUID = UUID(), content: String, category: String = "General", confidence: Double = 1.0, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.category = category
        self.confidence = confidence
        self.createdAt = createdAt
    }
}
