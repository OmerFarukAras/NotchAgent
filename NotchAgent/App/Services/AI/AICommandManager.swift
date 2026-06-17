//
//  AICommandManager.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Foundation
import AppKit

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

    private func buildSystemPrompt(defaultMusicApp: String, clipboardText: String?, recentFacts: [Fact]) -> String {
        let defaultMusicContext = defaultMusicApp.isEmpty
            ? "The default music provider is not set. If the user asks to play music, ask them what app they want to use by returning action: 'ask_clarification', summary: 'What is your default music app?'"
            : "The user's default music provider is \(defaultMusicApp). If they ask to play music without specifying an app, use this default. To change their default music app to X, output action: 'change_setting', target: 'default_music_app', script: 'X'."
            
        let clipboardContext = clipboardText != nil 
            ? "\n- The user's clipboard currently contains: \"\(clipboardText!)\". If the user asks you to summarize, rewrite, or explain without specifying what, they are likely referring to this text. Use the 'answer' action or 'type_text' action depending on context." 
            : ""

        return """
        You are a macOS desktop assistant embedded in a notch UI. The user gives voice commands.
        You MUST respond with ONLY a JSON object or a JSON array of objects in this exact format. If you need to perform multiple distinct actions, return an array of objects.
        For a single action, you can just return the object:
        {
          "action": "action_type",
          "target": "target_name_or_null",
          "script": "applescript_code_or_null",
          "confidence": 0.95,
          "summary": "Brief description of what you're doing",
          "needs_confirmation": false
        }

        Available actions:
        - "open_app": Open an application. Set "target" to the app name.
        - "open_url": Open a website. Set "target" to the URL (e.g. "https://github.com").
        - "open_urls": Open multiple websites in a browser. Set "target" to the browser app name (e.g. "Safari", "Google Chrome") and set "script" to one URL per line (e.g. "https://youtube.com\nhttps://github.com"). Use this for commands like "open Safari with YouTube and GitHub".
        - "music_control": Control music playback. Set "target" to "play", "pause", "next", "previous", "shuffle", "repeat".
        - "search_music": Search and play a specific song, artist, album, radio, chart, or playlist. Set "target" to the exact search query (e.g. "lvbelc5", "Motive", "Motive radio", "Motive Top 50", "araba musics piyasa"). If the user explicitly says Spotify, prefix the target with "spotify::"; if they explicitly say Apple Music, prefix it with "applemusic::".
        - "type_text": Dictate, paste, or type text into the currently active application. Set "script" to the exact text you want to type. Format it perfectly (e.g. if the user dictates code, format it as code).
        - "system_command": Run a system command. Set "script" to the AppleScript code.
        - "volume_control": Adjust system volume. Set "target" to "up", "down", "mute", or a number 0-100.
        - "brightness_control": Adjust screen brightness. Set "target" to "up", "down", or a number 0-100.
        - "web_search": Search the web. Set "target" to the search query.
        - "answer": Just answer a question. Set "summary" to the answer. No script needed.
        - "change_setting": Change a user setting. Set "target" to the setting name (e.g. "default_music_app") and "script" to the value.
        - "ask_clarification": If the command is too ambiguous, ask the user. Put your question in "summary".
        - "take_screenshot": If the user asks about the screen, what they are looking at, or uses words like 'buradaki', 'ekrandaki', 'bunu', output action: 'take_screenshot'. The system will take a screenshot and pass it back to you.
        - "unknown": You don't understand the command.

        Rules:
        - ONLY output the JSON object, nothing else.
        - Keep "summary" short (under 60 characters).
        - For AppleScript, use "tell application" syntax. You MUST escape inner quotes using backslashes (e.g. "tell application \"Safari\"").
        - Handle mixed language input robustly (e.g. Turkish and English). The speech-to-text system may misspell English app names phonetically (e.g. "kodex" -> "Codex", "anti graviti" -> "Anti Gravity"). You MUST correct these misspellings before executing the command.
        - Treat Turkish and English music commands as semantic search_music requests, not literal app-opening requests. Extract what the user wants to hear: artist, song, album, radio, chart, or playlist. The target must be the clean music search query, not the full sentence.
        - Music examples:
          - "Spotify'da Motive aç" -> action: "search_music", target: "spotify::Motive"
          - "Motive radyosu aç" -> action: "search_music", target: "Motive radio"
          - "Motive'yi Top 50 aç" -> action: "search_music", target: "Motive Top 50"
          - "Top 50 playlistini aç" -> action: "search_music", target: "Top 50 playlist"
          - "play Motive radio on Spotify" -> action: "search_music", target: "spotify::Motive radio"
          - "Apple Music'te Sezen Aksu çal" -> action: "search_music", target: "applemusic::Sezen Aksu"
        - Preserve stylized artist and song names. If the transcript sounds like "label c5", "level c5", "lvbel c5", "el ve bel c5", or "love bell c5" in a music command, normalize it to "lvbelc5"; do not replace it with the English word "level" or "label".
        - Respond in the same language as the user's command.
        - If you have a guessed action but are unsure, you can output the guessed action but set "needs_confirmation": true. If doing this, phrase your summary as a question (e.g. "Do you want to open GitHub?").
        - \(defaultMusicContext)\(clipboardContext)
        
        User Memory / Context:
        \(recentFacts.map { "- \($0.content)" }.joined(separator: "\n"))
        """
    }

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
            let shouldBypassCache = isMusicSearchIntent(transcript.lowercased(with: Locale(identifier: "tr_TR")))

            if let localCommand = localCommand(for: transcript) {
                let plan = CommandPlan(steps: [localCommand])
                lastPlan = plan
                if cacheEnabled {
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
        let recentFacts = MemoryManager.shared.fetchRecentFacts()
        
        do {
            let response = try await provider.generate(
                prompt: promptText,
                systemPrompt: buildSystemPrompt(defaultMusicApp: defaultMusicApp, clipboardText: clipboardText, recentFacts: recentFacts),
                image: nil,
                overrideModel: nil
            )

            var plan = CommandPlan.parse(from: response.text)

            // 3. Handle Screen Awareness (Vision) Round 2
            if plan?.steps.first?.action == "take_screenshot" {
                setPhase(.processing, message: "Taking screenshot...")
                
                if let screenshotData = takeScreenshot() {
                    setPhase(.processing, message: "Analyzing screen...")
                    
                    // Call the LLM again but using the vision model and the screenshot
                    let visionResponse = try await provider.generate(
                        prompt: "User's original request: '\(promptText)'. Look at this screenshot and fulfill their request.",
                        systemPrompt: buildSystemPrompt(defaultMusicApp: defaultMusicApp, clipboardText: clipboardText, recentFacts: recentFacts),
                        image: screenshotData,
                        overrideModel: visionModel
                    )
                    
                    plan = CommandPlan.parse(from: visionResponse.text)
                } else {
                    plan = CommandPlan(steps: [
                        ParsedCommand(
                            action: "answer",
                            target: nil,
                            script: nil,
                            confidence: 1.0,
                            summary: "Could not take screenshot. Please ensure Screen Recording permissions are granted in System Settings.",
                            needs_confirmation: false
                        )
                    ])
                }
            }

            if let finalPlan = plan, !finalPlan.steps.isEmpty {
                lastPlan = finalPlan
                lastResponse = response

                // Cache the result (caching first command only for backward compatibility, or update cache model later)
                let shouldBypassCache = isMusicSearchIntent(transcript.lowercased(with: Locale(identifier: "tr_TR")))
                if cacheEnabled && !shouldBypassCache {
                    MemoryManager.shared.cacheCommand(intent: transcript, response: response, command: finalPlan.steps.first!)
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
                    systemPrompt: buildSystemPrompt(defaultMusicApp: defaultMusicApp, clipboardText: clipboardText, recentFacts: []),
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
        Task { @MainActor in
            for command in plan.steps {
                let success = executeSingleCommand(command)
                if !success {
                    // Halt execution if a step explicitly failed
                    break
                }
                // Brief pause between sequential commands for stability
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    /// Execute a parsed command's AppleScript, if it has one. Returns true if successful.
    private func executeSingleCommand(_ command: ParsedCommand) -> Bool {
        let summary = command.summary ?? "Done"
        setPhase(.executing, message: "Running: \(summary)")

        if command.action == "ask_clarification" {
            setPhase(.done, message: summary)
            return true
        }

        if command.needs_confirmation == true {
            pendingCommand = command
            setPhase(.done, message: summary)
            return true
        }

        // Handle open_url natively
        if command.action == "open_url", let urlString = command.target, let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)") {
            NSWorkspace.shared.open(url)
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        // Handle multi-tab browser opens natively.
        if command.action == "open_urls",
           let browserName = command.target,
           let script = command.script {
            let urls = script
                .components(separatedBy: .newlines)
                .compactMap { normalizedURLString(from: $0) }

            guard !urls.isEmpty else {
                setPhase(.error, message: "No URLs to open")
                return false
            }

            openURLs(urls, inBrowser: browserName)
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        // Handle music_control natively
        if command.action == "music_control" {
            onMusicControl?(command.target ?? "playpause")
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        // Handle search_music natively
        if command.action == "search_music" {
            onMusicSearch?(command.target ?? "")
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        // Handle change_setting natively
        if command.action == "change_setting", let setting = command.target, let value = command.script {
            onSettingChange?(setting, value)
            setPhase(.done, message: "✓ \(summary)")
            return true
        }

        // Handle type_text natively
        if command.action == "type_text", let text = command.script {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            let source = """
            tell application "System Events"
                keystroke "v" using command down
            end tell
            """
            
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            
            if error != nil {
                setPhase(.error, message: "Needs Accessibility Permission")
                return false
            } else {
                setPhase(.done, message: "✓ Typed Text")
                return true
            }
        }

        // Handle open_app natively to bypass AppleScript sandbox restrictions
        if command.action == "open_app", let appName = command.target {
            let success = NSWorkspace.shared.launchApplication(appName)
            if success {
                setPhase(.done, message: "✓ \(summary)")
                return true
            } else {
                setPhase(.error, message: "Could not open \(appName)")
                return false
            }
        }
        
        guard let script = command.script, !script.isEmpty else {
            setPhase(.done, message: summary)
            return true
        }

        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)

        if error != nil {
            setPhase(.error, message: "Script execution failed")
            return false
        } else {
            setPhase(.done, message: "✓ \(summary)")
            return true
        }
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

    private func localCommand(for transcript: String) -> ParsedCommand? {
        if let command = browserTabsCommand(for: transcript) {
            return command
        }

        if shouldUseLocalMusicParser(for: transcript), let musicQuery = musicSearchQuery(from: transcript) {
            return ParsedCommand(
                action: "search_music",
                target: musicQuery,
                script: nil,
                confidence: 0.92,
                summary: "Playing \(musicQuery)",
                needs_confirmation: false
            )
        }

        return nil
    }

    private func shouldUseLocalMusicParser(for transcript: String) -> Bool {
        let lowercased = transcript.lowercased(with: Locale(identifier: "tr_TR"))
        let hasExplicitProvider = lowercased.contains("spotify") || lowercased.contains("apple music")
        let hasKnownSpeechCorrection = [
            "lvbel", "label c5", "labelc5", "level c5", "levelc5",
            "love bell c5", "lovebel c5", "el ve bel c5",
            "l v bel c5", "l v b l c 5"
        ].contains { lowercased.contains($0) }

        return hasExplicitProvider || hasKnownSpeechCorrection
    }

    private func browserTabsCommand(for transcript: String) -> ParsedCommand? {
        let lowercased = transcript.lowercased()
        guard lowercased.contains("open") || lowercased.contains("aç") else { return nil }

        let browserAliases: [(alias: String, appName: String)] = [
            ("safari", "Safari"),
            ("chrome", "Google Chrome"),
            ("google chrome", "Google Chrome"),
            ("edge", "Microsoft Edge"),
            ("firefox", "Firefox"),
            ("arc", "Arc")
        ]

        guard let browser = browserAliases.first(where: { lowercased.contains($0.alias) }) else {
            return nil
        }

        let separators = CharacterSet(charactersIn: ",+&")
        let cleaned = lowercased
            .replacingOccurrences(of: "open", with: " ")
            .replacingOccurrences(of: "aç", with: " ")
            .replacingOccurrences(of: browser.alias, with: " ")
            .replacingOccurrences(of: "with", with: " ")
            .replacingOccurrences(of: "and", with: ",")
            .replacingOccurrences(of: "ile", with: " ")
            .replacingOccurrences(of: "ve", with: ",")

        let urls = cleaned
            .components(separatedBy: separators)
            .compactMap { normalizedURLString(from: $0) }

        guard urls.count >= 2 else { return nil }

        return ParsedCommand(
            action: "open_urls",
            target: browser.appName,
            script: urls.joined(separator: "\n"),
            confidence: 0.94,
            summary: "Opening \(urls.count) tabs",
            needs_confirmation: false
        )
    }

    private func musicSearchQuery(from transcript: String) -> String? {
        let lowercased = transcript.lowercased(with: Locale(identifier: "tr_TR"))
        guard isMusicSearchIntent(lowercased) else { return nil }

        let providerPrefix: String
        if lowercased.contains("spotify") {
            providerPrefix = "spotify::"
        } else if lowercased.contains("apple music") || lowercased.contains("müzik uygulaması") || lowercased.contains("music uygulaması") {
            providerPrefix = "applemusic::"
        } else {
            providerPrefix = ""
        }

        var query = lowercased
        let replacements: [(String, String)] = [
            ("spotify'da", " "),
            ("spotify da", " "),
            ("spotifyda", " "),
            ("spotify", " "),
            ("apple music'te", " "),
            ("apple music te", " "),
            ("apple musicte", " "),
            ("apple music", " "),
            ("müzik uygulamasında", " "),
            ("music app", " "),
            ("please", " "),
            ("can you", " "),
            ("could you", " "),
            ("play", " "),
            ("open", " "),
            ("search", " "),
            ("put on", " "),
            ("açabilir misin", " "),
            ("açarmısın", " "),
            ("açar mısın", " "),
            ("aç", " "),
            ("çalabilir misin", " "),
            ("çalarmısın", " "),
            ("çalar mısın", " "),
            ("çal", " "),
            ("oynat", " "),
            ("başlat", " "),
            ("en iyi şarkılar", "best songs"),
            ("en sevilen şarkılar", "best songs"),
            ("popüler şarkılar", "popular songs"),
            ("şarkısını", " "),
            ("şarkısı", " "),
            ("şarkı", " "),
            ("parçasını", " "),
            ("parça", " "),
            ("playlistini", "playlist"),
            ("playlist'i", "playlist"),
            ("çalma listesini", "playlist"),
            ("listesini", " "),
            ("listesi", " "),
            ("radyosunu", "radio"),
            ("radyosu", "radio"),
            ("radyo", "radio"),
            (" radyoyu", " radio"),
            ("yi ", " "),
            ("yı ", " "),
            ("yu ", " "),
            ("yü ", " "),
            ("'yi", " "),
            ("'yı", " "),
            ("'yu", " "),
            ("'yü", " ")
        ]

        for (needle, replacement) in replacements {
            query = query.replacingOccurrences(of: needle, with: replacement)
        }

        query = query
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        query = stripTurkishObjectSuffixes(from: query)
        query = normalizeKnownMusicNames(query)

        guard isUsefulMusicQuery(query) else { return nil }
        return providerPrefix + titleCasedMusicQuery(query)
    }

    private func isMusicSearchIntent(_ lowercased: String) -> Bool {
        let musicWords = [
            "spotify", "apple music", "play", "çal", "oynat", "aç",
            "şarkı", "parça", "playlist", "çalma listesi", "radyo", "radyosu",
            "radio", "album", "albüm", "top 50", "top fifty", "motive",
            "lvbel", "label c5", "level c5"
        ]

        guard musicWords.contains(where: { lowercased.contains($0) }) else {
            return false
        }

        let nonMusicOpenTargets = ["safari", "chrome", "github", "youtube", "xcode", "cursor", "mail"]
        if lowercased.contains("aç") || lowercased.contains("open") {
            return !nonMusicOpenTargets.contains(where: { lowercased.contains($0) })
        }

        return true
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

    private func normalizedURLString(from rawValue: String) -> String? {
        let token = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard !token.isEmpty else { return nil }

        let aliases: [String: String] = [
            "youtube": "https://youtube.com",
            "you tube": "https://youtube.com",
            "github": "https://github.com",
            "git hub": "https://github.com",
            "google": "https://google.com",
            "gmail": "https://mail.google.com",
            "chatgpt": "https://chatgpt.com",
            "chat gpt": "https://chatgpt.com",
            "x": "https://x.com",
            "twitter": "https://x.com",
            "reddit": "https://reddit.com"
        ]

        if let alias = aliases[token] {
            return alias
        }

        if token.hasPrefix("http://") || token.hasPrefix("https://") {
            return token
        }

        if token.contains(".") && !token.contains(" ") {
            return "https://\(token)"
        }

        return nil
    }

    private func openURLs(_ urls: [String], inBrowser browserName: String) {
        let escapedBrowser = browserName.replacingOccurrences(of: "\"", with: "\\\"")
        let lines = urls.map { urlString in
            let escapedURL = urlString.replacingOccurrences(of: "\"", with: "\\\"")
            return "open location \"\(escapedURL)\""
        }.joined(separator: "\n    ")

        let source = """
        tell application "\(escapedBrowser)"
            activate
            \(lines)
        end tell
        """

        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
    }

    private func truncate(_ text: String, to length: Int) -> String {
        if text.count <= length { return text }
        return String(text.prefix(length)) + "…"
    }

    private func takeScreenshot() -> Data? {
        let path = NSTemporaryDirectory() + "notchagent_screenshot.jpg"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-t", "jpg", path]
        try? process.run()
        process.waitUntilExit()
        
        let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        try? FileManager.default.removeItem(atPath: path)
        return data
    }
}
