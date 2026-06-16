//
//  OllamaProvider.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Foundation

/// Ollama local LLM provider.
///
/// Communicates with a locally running Ollama instance via its HTTP API.
/// Default endpoint: `http://localhost:11434`.
final class OllamaProvider: LLMProvider, @unchecked Sendable {

    let name = "Ollama"

    private let session: URLSession
    private var baseURL: String
    private var model: String

    /// Timeout for generate requests (seconds).
    private let requestTimeout: TimeInterval = 15

    init(baseURL: String = "http://localhost:11434", model: String = "qwen2.5:3b") {
        self.baseURL = baseURL
        self.model = model

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout + 5
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration

    func updateBaseURL(_ url: String) {
        baseURL = url
    }

    func updateModel(_ modelName: String) {
        model = modelName
    }

    // MARK: - LLMProvider

    func checkAvailability() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }

        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func generate(prompt: String, systemPrompt: String?) async throws -> LLMResponse {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw LLMError.providerUnavailable(name)
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Build request body
        var body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]

        if let systemPrompt {
            body["system"] = systemPrompt
        }

        // Lower temperature for deterministic command generation
        body["options"] = [
            "temperature": 0.3,
            "num_predict": 256
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw LLMError.timeout
        } catch {
            throw LLMError.requestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw LLMError.requestFailed("HTTP \(statusCode)")
        }

        // Parse Ollama response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String
        else {
            throw LLMError.invalidResponse
        }

        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        return LLMResponse(
            text: responseText.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model,
            provider: name,
            latencyMs: latencyMs
        )
    }

    // MARK: - Model List

    /// Fetch available models from the Ollama instance.
    func fetchAvailableModels() async -> [String] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return [] }

        do {
            let (data, _) = try await session.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]]
            else { return [] }

            return models.compactMap { $0["name"] as? String }
        } catch {
            return []
        }
    }
}
