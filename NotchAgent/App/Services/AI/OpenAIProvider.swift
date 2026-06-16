//
//  OpenAIProvider.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Foundation

/// OpenAI-compatible API provider (OpenAI, Groq, Together, local vLLM, etc.).
///
/// Stub implementation — ready to be filled in for cloud-based providers.
final class OpenAIProvider: LLMProvider, @unchecked Sendable {

    let name = "OpenAI"

    private var apiKey: String
    private var baseURL: String
    private var model: String
    private let session: URLSession

    init(
        apiKey: String = "",
        baseURL: String = "https://api.openai.com/v1",
        model: String = "gpt-4o-mini"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration

    func updateAPIKey(_ key: String) {
        apiKey = key
    }

    func updateBaseURL(_ url: String) {
        baseURL = url
    }

    func updateModel(_ modelName: String) {
        model = modelName
    }

    // MARK: - LLMProvider

    func checkAvailability() async -> Bool {
        // Available only if API key is set
        !apiKey.isEmpty
    }

    func generate(prompt: String, systemPrompt: String?) async throws -> LLMResponse {
        guard !apiKey.isEmpty else {
            throw LLMError.providerUnavailable(name)
        }

        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw LLMError.providerUnavailable(name)
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        var messages: [[String: String]] = []
        if let systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }
        messages.append(["role": "user", "content": prompt])

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 256
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMError.invalidResponse
        }

        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        return LLMResponse(
            text: content.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model,
            provider: name,
            latencyMs: latencyMs
        )
    }
}
