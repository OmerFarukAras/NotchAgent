//
//  NotchState.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Foundation

enum NotchState: String, CaseIterable, Identifiable {
    case idle
    case listening
    case thinking
    case action
    case result
    case error
    case confirmation

    var id: String { rawValue }

    // MARK: - Presentation

    var symbolName: String {
        switch self {
        case .idle: "sparkles"
        case .listening: "waveform"
        case .thinking: "brain.head.profile"
        case .action: "bolt.fill"
        case .result: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .confirmation: "checkmark.seal.fill"
        }
    }

    var title: String {
        switch self {
        case .idle: "Notch Agent"
        case .listening: "Listening..."
        case .thinking: "Thinking..."
        case .action: "Running action..."
        case .result: "Done"
        case .error: "Something went wrong"
        case .confirmation: "Confirm action"
        }
    }

    var subtitle: String {
        switch self {
        case .idle: "Click to test the flow"
        case .listening: "Fake voice capture is active"
        case .thinking: "Preparing a response"
        case .action: "Dispatching command"
        case .result: "v0.1 shell is alive"
        case .error: "Try again"
        case .confirmation: "Waiting for approval"
        }
    }

    /// Whether this state shows a repeating pulse animation.
    var isPulsing: Bool {
        switch self {
        case .listening, .thinking, .action: true
        default: false
        }
    }
}
