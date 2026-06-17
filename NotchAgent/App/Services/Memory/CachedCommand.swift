//
//  CachedCommand.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 17.06.2026.
//

import Foundation
import SwiftData

@Model
final class CachedCommand {
    @Attribute(.unique) var intent: String
    var responseJSON: String
    var commandJSON: String?
    var cachedAt: Date
    var hitCount: Int

    init(intent: String, responseJSON: String, commandJSON: String?, cachedAt: Date = Date(), hitCount: Int = 0) {
        self.intent = intent
        self.responseJSON = responseJSON
        self.commandJSON = commandJSON
        self.cachedAt = cachedAt
        self.hitCount = hitCount
    }
}
