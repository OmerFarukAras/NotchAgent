//
//  SpeechSynthesizer.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 16.06.2026.
//

import AppKit

/// Simple text-to-speech wrapper using macOS NSSpeechSynthesizer.
@MainActor
final class SpeechSynthesizer: NSObject, NSSpeechSynthesizerDelegate {
    private let synthesizer = NSSpeechSynthesizer()
    
    private var utteranceQueue: [String] = []
    
    /// The sentence currently being spoken. Used for interruption context.
    private(set) var currentUtteranceText: String?
    
    /// Collected context to be sent to the AI upon interruption.
    private(set) var interruptionContext: String?

    override init() {
        super.init()
        synthesizer.delegate = self
        // Find a natural Siri voice if available, otherwise default
        let voices = NSSpeechSynthesizer.availableVoices
        if let siriVoice = voices.first(where: { $0.rawValue.lowercased().contains("siri") }) {
            synthesizer.setVoice(siriVoice)
        }
    }

    /// Speaks the given text by splitting it into smaller chunks, stopping any currently playing speech.
    func speak(_ text: String) {
        synthesizer.stopSpeaking()
        utteranceQueue.removeAll()
        currentUtteranceText = nil
        interruptionContext = nil
        
        // Simple sentence chunking
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".?!"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        utteranceQueue = sentences
        speakNext()
    }
    
    private func speakNext() {
        guard !utteranceQueue.isEmpty else {
            currentUtteranceText = nil
            return
        }
        let nextUtterance = utteranceQueue.removeFirst()
        currentUtteranceText = nextUtterance
        synthesizer.startSpeaking(nextUtterance)
    }

    /// Pauses the current reading, storing the current sentence as interruption context.
    func pause() {
        if synthesizer.isSpeaking {
            interruptionContext = currentUtteranceText
            synthesizer.pauseSpeaking(at: .immediateBoundary)
        }
    }
    
    /// Resumes speaking from where it was paused.
    func resume() {
        if interruptionContext != nil {
            synthesizer.continueSpeaking()
            interruptionContext = nil
        } else if !utteranceQueue.isEmpty && !synthesizer.isSpeaking {
            speakNext()
        }
    }

    /// Stops any currently playing speech and clears the queue.
    func stop() {
        synthesizer.stopSpeaking()
        utteranceQueue.removeAll()
        currentUtteranceText = nil
        interruptionContext = nil
    }
    
    // MARK: - NSSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ sender: NSSpeechSynthesizer, didFinishSpeaking finishedSpeaking: Bool) {
        Task { @MainActor in
            // Only proceed if it naturally finished (not stopped/paused manually)
            if finishedSpeaking {
                self.speakNext()
            }
        }
    }
}
