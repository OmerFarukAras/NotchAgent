//
//  SoundEffectPlayer.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 16.06.2026.
//

import AppKit

/// Helper to play system sounds for phase changes.
enum SoundEffectPlayer {
    
    enum Effect {
        case startListening
        case stopListening
        case success
        case error
        
        var soundName: NSSound.Name {
            switch self {
            case .startListening:
                return NSSound.Name("Tink")
            case .stopListening:
                return NSSound.Name("Pop")
            case .success:
                return NSSound.Name("Hero")
            case .error:
                return NSSound.Name("Basso")
            }
        }
    }
    
    static func play(_ effect: Effect) {
        if let sound = NSSound(named: effect.soundName) {
            sound.play()
        }
    }
}
