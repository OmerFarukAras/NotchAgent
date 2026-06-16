//
//  SpeechSynthesizer.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 16.06.2026.
//

import AppKit

/// Simple text-to-speech wrapper using macOS NSSpeechSynthesizer.
@MainActor
final class SpeechSynthesizer {
    private let synthesizer = NSSpeechSynthesizer()

    init() {
        // Find a natural Siri voice if available, otherwise default
        let voices = NSSpeechSynthesizer.availableVoices
        if let siriVoice = voices.first(where: { $0.rawValue.lowercased().contains("siri") }) {
            synthesizer.setVoice(siriVoice)
        }
    }

    /// Speaks the given text, stopping any currently playing speech.
    func speak(_ text: String) {
        synthesizer.stopSpeaking()
        synthesizer.startSpeaking(text)
    }

    /// Stops any currently playing speech.
    func stop() {
        synthesizer.stopSpeaking()
    }
}
