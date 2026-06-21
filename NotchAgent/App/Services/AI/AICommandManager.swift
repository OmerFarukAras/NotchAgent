//
//  AICommandManager.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Orchestrates the full AI command pipeline:
///
/// ```
/// Push-to-talk start → STT (partial results → UI)
/// Push-to-talk stop  → Final transcript
///                    → Cache check
///                    → (miss) LLM generate → Cache store
///                    → Parse command → Execute
/// ```
///
/// Owns the `SpeechRecognizer`, `CommandCache`, and active `LLMProvider`.
@MainActor
final class AICommandManager {

    // MARK: - Dependencies

    private let speechRecognizer = SpeechRecognizer()
    private let speechSynthesizer = SpeechSynthesizer()
    private let cacheEnabledKey = "notchagent.cacheEnabled"
    private let commandExecutor = CommandExecutor()

    private var ollamaProvider: OllamaProvider
    private var openAIProvider: OpenAIProvider

    // MARK: - State

    private(set) var phase: AgentPhase = .idle
    private(set) var lastTranscript = ""
    private(set) var lastResponse: LLMResponse?
    private(set) var lastPlan: CommandPlan?
    private(set) var wasCacheHit = false
    private(set) var pendingCommand: ParsedCommand?

    /// Called when a setting is changed by the AI (e.g. default_music_app).
    var onSettingChange: ((String, String) -> Void)?

    /// Called to execute music controls natively.
    var onMusicControl: ((String) -> Void)?

    /// Called to search and play music natively.
    var onMusicSearch: ((String) -> Void)?

    /// Called when the pipeline phase changes — used to update AppState.
    var onPhaseChange: ((AgentPhase, String) -> Void)?

    /// Called with each partial transcript from STT.
    var onTranscriptUpdate: ((String) -> Void)?

    /// Called with the audio input level for the waveform.
    var onLevelChange: ((Double) -> Void)?

    /// Called when a command plan has been parsed and is ready to display/execute.
    var onPlanReady: ((CommandPlan, Bool) -> Void)?

    /// Called when silence is detected.
    var onSilenceDetected: (() -> Void)?

    // MARK: - System Prompt

    // MARK: - Init

    init() {
        self.ollamaProvider = OllamaProvider()
        self.openAIProvider = OpenAIProvider()

        // Wire speech recognizer callbacks
        speechRecognizer.onPartialTranscript = { [weak self] transcript in
            self?.lastTranscript = transcript
            self?.onTranscriptUpdate?(transcript)
        }

        speechRecognizer.onLevelChange = { [weak self] level in
            self?.onLevelChange?(level)
        }

        speechRecognizer.onSilenceDetected = { [weak self] in
            self?.onSilenceDetected?()
        }

        commandExecutor.onPhaseChange = { [weak self] phase, msg in
            self?.setPhase(phase, message: msg)
        }
        commandExecutor.onMusicControl = { [weak self] action in
            self?.onMusicControl?(action)
        }
        commandExecutor.onMusicSearch = { [weak self] query in
            self?.onMusicSearch?(query)
        }
        commandExecutor.onSettingChange = { [weak self] setting, value in
            self?.onSettingChange?(setting, value)
        }
        commandExecutor.onPendingCommand = { [weak self] command in
            self?.pendingCommand = command
        }
        commandExecutor.onBackgroundResearchSummarize = { [weak self] query, rawText in
            guard let self = self else { return rawText }
            let prompt = "Kullanıcı şu konuyu araştırmak istedi: '\\(query)'. Bulunan ham veriler şunlar:\\n\\n\\(rawText)\\n\\nLütfen bu verileri okuyarak kullanıcıya kısa, öz ve konuşma dilinde bir özet yaz."
            let response = try await self.ollamaProvider.generate(prompt: prompt, systemPrompt: "Sen yardımsever bir asistansın. Sadece istenen özeti ver.", image: nil, overrideModel: nil)
            return response.text
        }
    }

    // MARK: - Provider Configuration

    func configureOllama(baseURL: String, model: String) {
        ollamaProvider.updateBaseURL(baseURL)
        ollamaProvider.updateModel(model)
    }

    func configureOpenAI(apiKey: String, baseURL: String, model: String) {
        openAIProvider.updateAPIKey(apiKey)
        openAIProvider.updateBaseURL(baseURL)
        openAIProvider.updateModel(model)
    }

    func configureSpeechRecognition(engine: String, whisperExecutablePath: String, whisperModelPath: String) {
        speechRecognizer.updateConfiguration(
            SpeechRecognitionConfiguration(
                engine: SpeechRecognitionEngine(rawValue: engine) ?? .automatic,
                whisperExecutablePath: whisperExecutablePath,
                whisperModelPath: whisperModelPath
            )
        )
    }

    /// Get the currently active provider based on the selected provider name.
    private func activeProvider(named name: String) -> LLMProvider {
        switch name {
        case "OpenAI":
            openAIProvider
        default:
            ollamaProvider
        }
    }

    // MARK: - Pipeline Control

    /// Start listening (push-to-talk press).
    func activate(playSounds: Bool) async {
        guard phase == .idle || phase == .done || phase == .error else { return }

        setPhase(.listening, message: "Listening...")
        lastTranscript = ""
        lastResponse = nil
        lastPlan = nil
        wasCacheHit = false
        speechSynthesizer.stop()

        if playSounds {
            SoundEffectPlayer.play(.startListening)
        }

        do {
            try await speechRecognizer.start()
        } catch {
            setPhase(.error, message: error.localizedDescription)
            if playSounds { SoundEffectPlayer.play(.error) }
        }
    }

    /// Stop listening and process the transcript (push-to-talk release).
    func processCommand(providerName: String, defaultMusicApp: String, clipboardText: String?, visionModel: String, cacheEnabled: Bool, playSounds: Bool, voiceFeedback: Bool) async {
        guard phase == .listening else { return }

        if playSounds {
            SoundEffectPlayer.play(.stopListening)
        }

        setPhase(.processing, message: "Transcribing...")

        let transcript: String
        do {
            transcript = try await speechRecognizer.stopAndTranscribe()
        } catch {
            setPhase(.error, message: error.localizedDescription)
            if playSounds { SoundEffectPlayer.play(.error) }
            return
        }

        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setPhase(.idle, message: "No speech detected")
            return
        }

        lastTranscript = transcript
        setPhase(.processing, message: "Processing: \(truncate(transcript, to: 40))")
        
        var promptText = transcript
        if let pending = pendingCommand {
            promptText = """
            You previously tried to execute this command but needed clarification or confirmation:
            \(pending.jsonString)
            
            You asked the user: '\(pending.summary ?? "")'.
            The user just replied: '\(transcript)'.
            
            Based on their reply, output the final correct JSON command (set needs_confirmation to false).
            If they are answering a question to set a default app, output action: 'change_setting' with target 'default_music_app'.
            If they confirmed the action, output the correct command.
            Otherwise, ignore the pending context and process the new command normally.
            """
            pendingCommand = nil
        } else {
            let shouldBypassCache = shouldBypassCommandCache(for: transcript)
            if shouldBypassCache {
                MemoryManager.shared.removeCachedCommand(intent: transcript)
            }

            if let localCommand = CommandParser.localCommand(for: transcript) {
                let plan = CommandPlan(steps: [localCommand])
                lastPlan = plan
                if cacheEnabled && shouldCacheCommand(localCommand, for: transcript, usedScreenContext: false) {
                    MemoryManager.shared.cacheCommand(
                        intent: transcript,
                        response: LLMResponse(
                            text: localCommand.jsonString,
                            model: "local-rules",
                            provider: "local",
                            latencyMs: 0
                        ),
                        command: localCommand
                    )
                }

                let summary = localCommand.summary ?? "Done"
                setPhase(.done, message: summary)
                if playSounds { SoundEffectPlayer.play(.success) }
                if voiceFeedback { speechSynthesizer.speak(summary) }
                onPlanReady?(plan, false)
                return
            }

            // Only check cache if there is no pending confirmation
            if cacheEnabled, !shouldBypassCache, let cached = MemoryManager.shared.lookupCommand(intent: transcript) {
                wasCacheHit = true
                
                if let responseData = cached.responseJSON.data(using: .utf8),
                   let response = try? JSONDecoder().decode(LLMResponse.self, from: responseData) {
                    lastResponse = response
                }
                
                if let commandJSON = cached.commandJSON,
                   let commandData = commandJSON.data(using: .utf8),
                   let command = try? JSONDecoder().decode(ParsedCommand.self, from: commandData) {
                    let plan = CommandPlan(steps: [command])
                    lastPlan = plan
                    let summary = command.summary ?? "Done"
                    setPhase(.done, message: "⚡ \(summary)")
                    if playSounds { SoundEffectPlayer.play(.success) }
                    if voiceFeedback { speechSynthesizer.speak(summary) }
                    onPlanReady?(plan, true)
                } else {
                    lastPlan = nil
                    setPhase(.done, message: "⚡ Cache hit")
                }
                return
            }
        }

        // 2. Generate initial command
        let provider = activeProvider(named: providerName)
        let memoryFacts = await VectorMemoryService.shared.search(query: transcript)
        let recentFacts = memoryFacts.map { $0.text }
        
        do {
            if pendingCommand == nil, isScreenAwarenessIntent(transcript.lowercased(with: Locale(identifier: "tr_TR"))) {
                setPhase(.processing, message: "Taking screenshot...")

                guard let screenshotData = await takeScreenshot() else {
                    let command = ParsedCommand(
                        action: "answer",
                        target: nil,
                        script: nil,
                        confidence: 1.0,
                        summary: "Screen Recording permission is needed. If you just enabled it, restart NotchAgent.",
                        needs_confirmation: false
                    )
                    let plan = CommandPlan(steps: [command])
                    lastPlan = plan
                    lastResponse = nil
                    setPhase(.done, message: command.summary ?? "Permission needed")
                    if playSounds { SoundEffectPlayer.play(.error) }
                    if voiceFeedback { speechSynthesizer.speak(command.summary ?? "Permission needed") }
                    onPlanReady?(plan, false)
                    return
                }

                setPhase(.processing, message: "Analyzing screen...")
                let visionResponse = try await provider.generate(
                    prompt: "User request: '\(promptText)'. Use the screenshot to guide the user. YOU MUST ONLY OUTPUT VALID JSON. No other text.",
                    systemPrompt: PromptBuilder.buildVisionSystemPrompt(defaultMusicApp: defaultMusicApp, clipboardText: clipboardText, recentFacts: recentFacts),
                    image: screenshotData,
                    overrideModel: visionModel
                )

                let plan = planFromVisionResponse(visionResponse)
                lastPlan = plan
                lastResponse = visionResponse

                let summary = plan.steps.first?.summary ?? "Done"
                setPhase(.done, message: summary)
                if playSounds { SoundEffectPlayer.play(.success) }
                if voiceFeedback { speechSynthesizer.speak(summary) }
                onPlanReady?(plan, false)

                extractAndSaveVisualFacts(
                    from: transcript,
                    screenshotData: screenshotData,
                    defaultMusicApp: defaultMusicApp,
                    clipboardText: clipboardText,
                    recentFacts: recentFacts,
                    provider: provider,
                    visionModel: visionModel
                )
                return
            }

            let response = try await provider.generate(
                prompt: promptText,
                systemPrompt: PromptBuilder.buildSystemPrompt(defaultMusicApp: defaultMusicApp, clipboardText: clipboardText, recentFacts: recentFacts),
                image: nil,
                overrideModel: nil
            )

            var plan = CommandPlan.parse(from: response.text)
            var usedScreenContext = false

            // 3. Handle Screen Awareness (Vision) Round 2
            if plan?.steps.first?.action == "take_screenshot" {
                usedScreenContext = true
                setPhase(.processing, message: "Taking screenshot...")
                
                if let screenshotData = await takeScreenshot() {
                    setPhase(.processing, message: "Analyzing screen...")
                    
                    // Call the LLM again but using the vision model and the screenshot
                    let visionResponse = try await provider.generate(
                        prompt: "User's original request: '\(promptText)'. Look at this screenshot and fulfill their request.",
                        systemPrompt: PromptBuilder.buildVisionSystemPrompt(defaultMusicApp: defaultMusicApp, clipboardText: clipboardText, recentFacts: recentFacts),
                        image: screenshotData,
                        overrideModel: visionModel
                    )
                    
                    plan = planFromVisionResponse(visionResponse)
                    extractAndSaveVisualFacts(
                        from: transcript,
                        screenshotData: screenshotData,
                        defaultMusicApp: defaultMusicApp,
                        clipboardText: clipboardText,
                        recentFacts: recentFacts,
                        provider: provider,
                        visionModel: visionModel
                    )
                } else {
                    plan = CommandPlan(steps: [
                        ParsedCommand(
                            action: "answer",
                            target: nil,
                            script: nil,
                            confidence: 1.0,
                            summary: "Screen Recording permission is needed. If you just enabled it, restart NotchAgent.",
                            needs_confirmation: false
                        )
                    ])
                }
            }

            if let finalPlan = plan, !finalPlan.steps.isEmpty {
                lastPlan = finalPlan
                lastResponse = response

                // Cache the result (caching first command only for backward compatibility, or update cache model later)
                let shouldBypassCache = shouldBypassCommandCache(for: transcript) || usedScreenContext
                if let firstCommand = finalPlan.steps.first,
                   cacheEnabled,
                   !shouldBypassCache,
                   shouldCacheCommand(firstCommand, for: transcript, usedScreenContext: usedScreenContext) {
                    MemoryManager.shared.cacheCommand(intent: transcript, response: response, command: firstCommand)
                }

                let summary = finalPlan.steps.first?.summary ?? "Done"
                setPhase(.done, message: summary)
                if playSounds { SoundEffectPlayer.play(.success) }
                if voiceFeedback { speechSynthesizer.speak(summary) }
                onPlanReady?(finalPlan, false)
                
                // Extract and save facts asynchronously
                extractAndSaveFacts(from: transcript, defaultMusicApp: defaultMusicApp, clipboardText: clipboardText, provider: provider)
            } else {
                // LLM returned something but it's not valid JSON
                setPhase(.done, message: truncate(response.text, to: 50))
                if playSounds { SoundEffectPlayer.play(.error) }
            }
        } catch {
            setPhase(.error, message: error.localizedDescription)
            if playSounds { SoundEffectPlayer.play(.error) }
        }
    }

    private func extractAndSaveFacts(from transcript: String, defaultMusicApp: String, clipboardText: String?, provider: LLMProvider) {
        Task {
            let prompt = "Extract any new personal facts, preferences, or important information about the user from this message: '\(transcript)'. Return ONLY a JSON object with action: 'save_fact', target: 'category (e.g. General, Personal, Music)', script: 'the fact text'. If there is nothing to save, return action: 'unknown'."
            do {
                let response = try await provider.generate(
                    prompt: prompt,
                    systemPrompt: PromptBuilder.buildSystemPrompt(defaultMusicApp: defaultMusicApp, clipboardText: clipboardText, recentFacts: []),
                    image: nil,
                    overrideModel: nil
                )
                if let plan = CommandPlan.parse(from: response.text),
                   let command = plan.steps.first,
                   command.action == "save_fact",
                   let fact = command.script {
                    MemoryManager.shared.addFact(content: fact, category: command.target ?? "General")
                }
            } catch {
                print("Fact extraction failed: \(error)")
            }
        }
    }

    private func extractAndSaveVisualFacts(
        from transcript: String,
        screenshotData: Data,
        defaultMusicApp: String,
        clipboardText: String?,
        recentFacts: [String],
        provider: LLMProvider,
        visionModel: String
    ) {
        guard shouldExtractVisualFact(from: transcript) else { return }

        Task {
            let prompt = """
            The user just referred to this screenshot with: "\(transcript)".
            If they taught a stable visual fact or identity cue, return ONLY JSON:
            {"action":"save_fact","target":"Visual","script":"short durable fact to remember","confidence":0.9,"summary":"Saved","needs_confirmation":false}
            Otherwise return:
            {"action":"unknown","target":null,"script":null,"confidence":0.0,"summary":"Nothing to save","needs_confirmation":false}

            Save only durable, user-provided facts. For "this is me" / "bu benim", describe the visible person as a user-taught visual identity cue without claiming biometric certainty.
            """

            do {
                let response = try await provider.generate(
                    prompt: prompt,
                    systemPrompt: PromptBuilder.buildVisionSystemPrompt(defaultMusicApp: defaultMusicApp, clipboardText: clipboardText, recentFacts: recentFacts),
                    image: screenshotData,
                    overrideModel: visionModel
                )

                if let plan = CommandPlan.parse(from: response.text),
                   let command = plan.steps.first,
                   command.action == "save_fact",
                   let fact = command.script,
                   !fact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MemoryManager.shared.addFact(content: fact, category: command.target ?? "Visual")
                }
            } catch {
                print("Visual fact extraction failed: \(error)")
            }
        }
    }

    /// Cancel any in-progress operation and reset to idle.
    func reset() {
        speechRecognizer.cancel()
        speechSynthesizer.stop()
        lastTranscript = ""
        lastResponse = nil
        lastPlan = nil
        pendingCommand = nil
        wasCacheHit = false
        setPhase(.idle, message: "Ready for a quick command")
    }

    // MARK: - Command Execution

    func executeCommandPlan(_ plan: CommandPlan) {
        commandExecutor.executeCommandPlan(plan)
    }

    // MARK: - Health Check

    /// Check if the specified provider is available.
    func checkProviderHealth(named name: String) async -> Bool {
        await activeProvider(named: name).checkAvailability()
    }

    /// Fetch available Ollama models.
    func fetchOllamaModels() async -> [String] {
        await ollamaProvider.fetchAvailableModels()
    }

    // MARK: - Cache Access

    /// Get the number of currently cached commands.
    var cacheEntryCount: Int { MemoryManager.shared.getCacheCount() }

    /// Clear all cached commands.
    func clearCache() {
        MemoryManager.shared.clearCache()
    }

    // MARK: - Private

    private func setPhase(_ phase: AgentPhase, message: String) {
        self.phase = phase
        onPhaseChange?(phase, message)
    }

    private func shouldBypassCommandCache(for transcript: String) -> Bool {
        let lowercased = transcript.lowercased(with: Locale(identifier: "tr_TR"))
        return CommandParser.isMusicSearchIntent(lowercased)
            || isScreenAwarenessIntent(lowercased)
            || containsDynamicAnswerIntent(lowercased)
    }

    private func shouldCacheCommand(_ command: ParsedCommand, for transcript: String, usedScreenContext: Bool) -> Bool {
        guard !usedScreenContext,
              command.needs_confirmation != true,
              let action = command.action else {
            return false
        }

        let lowercased = transcript.lowercased(with: Locale(identifier: "tr_TR"))
        guard !containsDynamicAnswerIntent(lowercased), !isScreenAwarenessIntent(lowercased) else {
            return false
        }

        let cacheableActions = Set([
            "open_app",
            "open_url",
            "open_urls",
            "volume_control",
            "brightness_control",
            "change_setting"
        ])

        return cacheableActions.contains(action)
    }

    private func containsDynamicAnswerIntent(_ lowercased: String) -> Bool {
        let dynamicWords = [
            "what", "why", "how", "when", "where", "who",
            "ne", "neden", "nasıl", "nasil", "niye", "kim", "hangi",
            "bugün", "bugun", "şimdi", "simdi", "currently", "latest",
            "açıkla", "acikla", "özetle", "ozetle", "anlat", "yorumla",
            "answer", "explain", "summarize", "describe"
        ]

        return dynamicWords.contains { lowercased.contains($0) }
    }

    private func isScreenAwarenessIntent(_ lowercased: String) -> Bool {
        let screenWords = [
            "screen", "screenshot", "display", "monitor", "what am i looking at",
            "what is on my screen", "what's on my screen", "look at this",
            "ekran", "ekranım", "ekranim", "ekrandaki", "ekranda",
            "buradaki", "burda", "burada", "bunu", "şunu", "sunu",
            "gördüğüm", "gordugum", "ne var", "ne görüyorsun", "ne goruyorsun",
            "how do i open", "nasıl açarım", "nasil acarim", "nerede", "where is"
        ]

        return screenWords.contains { lowercased.contains($0) }
    }

    private func shouldExtractVisualFact(from transcript: String) -> Bool {
        let lowercased = transcript.lowercased(with: Locale(identifier: "tr_TR"))
        let teachingPhrases = [
            "bu benim", "bu ben", "beni tanı", "beni tani", "bunu hatırla",
            "bunu hatirla", "aklında tut", "aklinda tut", "remember this",
            "this is me", "that's me", "that is me", "remember me",
            "recognize me", "learn this"
        ]

        return teachingPhrases.contains { lowercased.contains($0) }
    }

    private func planFromVisionResponse(_ response: LLMResponse) -> CommandPlan {
        if let plan = CommandPlan.parse(from: response.text), !plan.steps.isEmpty {
            return plan
        }

        return CommandPlan(steps: [
            ParsedCommand(
                action: "answer",
                target: nil,
                script: nil,
                confidence: 0.8,
                summary: truncate(response.text, to: 120),
                needs_confirmation: false
            )
        ])
    }

    private func normalizeKnownMusicNames(_ query: String) -> String {
        var normalized = query
        let knownReplacements: [(String, String)] = [
            ("level c5", "lvbelc5"),
            ("levelc5", "lvbelc5"),
            ("label c5", "lvbelc5"),
            ("labelc5", "lvbelc5"),
            ("lvbel c5", "lvbelc5"),
            ("love bell c5", "lvbelc5"),
            ("lovebel c5", "lvbelc5"),
            ("el ve bel c5", "lvbelc5"),
            ("l v bel c5", "lvbelc5"),
            ("l v b l c 5", "lvbelc5"),
            ("motive top fifty", "motive top 50"),
            ("top fifty", "top 50")
        ]

        for (needle, replacement) in knownReplacements {
            normalized = normalized.replacingOccurrences(of: needle, with: replacement)
        }

        return normalized
    }

    private func stripTurkishObjectSuffixes(from query: String) -> String {
        query
            .split(separator: " ")
            .map { word -> String in
                var value = String(word).trimmingCharacters(in: CharacterSet(charactersIn: "'’"))
                let suffixes = ["lerini", "larını", "ini", "ını", "unu", "ünü", "yi", "yı", "yu", "yü"]

                for suffix in suffixes where value.count > suffix.count + 1 && value.hasSuffix(suffix) {
                    value.removeLast(suffix.count)
                    break
                }

                return value
            }
            .joined(separator: " ")
    }

    private func isUsefulMusicQuery(_ query: String) -> Bool {
        guard query.count >= 2 else { return false }
        let banned = Set(["spotify", "apple music", "music", "şarkı", "playlist", "radio", "radyo"])
        return !banned.contains(query)
    }

    private func titleCasedMusicQuery(_ query: String) -> String {
        if query == "lvbelc5" { return "lvbelc5" }
        return query
            .split(separator: " ")
            .map { part in
                if part == "lvbelc5" { return String(part) }
                if part.allSatisfy(\.isNumber) { return String(part) }
                if part == "radio" || part == "playlist" { return String(part) }
                return part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }

    private func truncate(_ text: String, to length: Int) -> String {
        if text.count <= length { return text }
        return String(text.prefix(length)) + "…"
    }

    private func takeScreenshot() async -> Data? {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            return nil
        }

        do {
            let content = try await SCShareableContent.current
            let mainDisplayID = CGMainDisplayID()
            guard let display = content.displays.first(where: { $0.displayID == mainDisplayID }) ?? content.displays.first else {
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            let scale = NSScreen.screens
                .first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID })?
                .backingScaleFactor ?? 1
            configuration.width = Int(display.width) * Int(scale)
            configuration.height = Int(display.height) * Int(scale)

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            let bitmap = NSBitmapImageRep(cgImage: image)
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
        } catch {
            return nil
        }
    }
}
