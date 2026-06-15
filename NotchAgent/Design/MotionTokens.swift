//
//  MotionTokens.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import SwiftUI

// MARK: - Animation Tokens

extension Animation {

    // Notch expand / collapse
    static let notchExpand = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let notchCollapse = Animation.spring(response: 0.32, dampingFraction: 0.90)

    // Surface open / close
    static let surfaceTransition = Animation.spring(response: 0.40, dampingFraction: 0.86)

    // State icon change
    static let stateChange = Animation.easeInOut(duration: 0.18)

    // Indicator pulses
    static let listeningPulse = Animation.easeInOut(duration: 0.64).repeatForever(autoreverses: true)
    static let thinkingPulse = Animation.easeInOut(duration: 0.82).repeatForever(autoreverses: true)
    static let actionPulse = Animation.easeInOut(duration: 0.42).repeatForever(autoreverses: true)
    static let stateReset = Animation.easeOut(duration: 0.18)

    /// Returns the correct repeating pulse animation for a given agent state.
    static func indicatorPulse(for state: NotchState) -> Animation {
        switch state {
        case .listening: .listeningPulse
        case .thinking: .thinkingPulse
        case .action: .actionPulse
        default: .stateReset
        }
    }
}

// MARK: - Duration Constants

enum Motion {
    // Window fade
    static let windowShowDuration: TimeInterval = 0.18
    static let windowHideDuration: TimeInterval = 0.16
    static let windowHideDelay: Duration = .milliseconds(170)

    // Demo flow timings
    static let demoListeningDuration: Duration = .seconds(2)
    static let demoResultDuration: Duration = .seconds(1.2)
}
