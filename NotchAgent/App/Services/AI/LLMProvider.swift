//
//  LLMProvider.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Foundation

// MARK: - Provider Protocol

/// Abstract interface for all AI model providers.
///
/// Each provider (Ollama, OpenAI, etc.) implements this protocol.
/// The `AICommandManager` uses it to send prompts and receive structured responses.
protocol LLMProvider: Sendable {
    /// Human-readable provider name (e.g. "Ollama", "OpenAI").
    var name: String { get }

    /// Check whether the provider backend is reachable.
    func checkAvailability() async -> Bool

    /// Send a prompt to the model and return a structured response.
    ///
    /// - Parameters:
    ///   - prompt: The user's intent or transcribed command.
    ///   - systemPrompt: Optional system-level instruction for the model.
    /// - Returns: A parsed `LLMResponse`.
    func generate(prompt: String, systemPrompt: String?) async throws -> LLMResponse
}

// MARK: - Response

/// Structured response from any LLM provider.
struct LLMResponse: Sendable, Codable {
    /// The raw text returned by the model.
    let text: String
    /// The specific model used (e.g. "qwen2.5:3b").
    let model: String
    /// Provider name that produced this response.
    let provider: String
    /// Round-trip latency in milliseconds.
    let latencyMs: Int
}

// MARK: - Parsed Command

/// Structured command extracted from LLM JSON output.
///
/// The LLM is instructed to return JSON in this shape:
/// ```json
/// {
///   "action": "open_app",
///   "target": "Spotify",
///   "script": "tell application \"Spotify\" to activate",
///   "confidence": 0.95,
///   "summary": "Opening Spotify"
/// }
/// ```
struct ParsedCommand: Sendable, Codable {
    let action: String?
    let target: String?
    let script: String?
    let confidence: Double?
    let summary: String?
    let needs_confirmation: Bool?

    var jsonString: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    /// Try to decode a `ParsedCommand` from raw LLM text.
    ///
    /// The LLM may wrap JSON in markdown fences — this handles that.
    static func parse(from text: String) -> ParsedCommand? {
        // Find the first '{' and last '}' to extract the JSON object, 
        // ignoring any conversational prefix/suffix or markdown blocks.
        guard let startFirst = text.firstIndex(of: "{"),
              let endLast = text.lastIndex(of: "}"),
              startFirst < endLast else {
            return nil
        }
        
        let jsonSubstring = text[startFirst...endLast]
        guard let data = String(jsonSubstring).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParsedCommand.self, from: data)
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case providerUnavailable(String)
    case requestFailed(String)
    case invalidResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let name):
            "Provider \(name) is not available"
        case .requestFailed(let detail):
            "Request failed: \(detail)"
        case .invalidResponse:
            "Could not parse model response"
        case .timeout:
            "Request timed out"
        }
    }
}
