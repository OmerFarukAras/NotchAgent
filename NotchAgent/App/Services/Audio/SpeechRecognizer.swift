//
//  SpeechRecognizer.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import Foundation
import Speech
import AVFoundation

/// Push-to-talk speech-to-text using Apple Speech or a local whisper.cpp binary.
@MainActor
final class SpeechRecognizer {

    // MARK: - Callbacks

    /// Called on the main actor with each partial transcript update.
    var onPartialTranscript: ((String) -> Void)?

    /// Called on the main actor with audio input level (0...1) for the waveform UI.
    var onLevelChange: ((Double) -> Void)?

    /// Called when silence is detected for more than the threshold after speech has started.
    var onSilenceDetected: (() -> Void)?

    // MARK: - State

    private(set) var isRunning = false
    private(set) var finalTranscript = ""

    private var configuration = SpeechRecognitionConfiguration()
    private var activeEngine: SpeechRecognitionEngine = .appleSpeech

    // MARK: - Audio & Speech

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var whisperAudioFile: AVAudioFile?
    private var whisperAudioURL: URL?
    private var smoothingLevel: Double = 0

    // Silence detection state
    private var lastSpeechDetectedTime: Date?
    private var hasTriggeredSilence = false
    private let silenceThresholdSeconds: TimeInterval = 2.0
    private let speechLevelThreshold: Double = 0.08

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    }

    // MARK: - Public API

    func updateConfiguration(_ configuration: SpeechRecognitionConfiguration) {
        self.configuration = configuration
    }

    /// Request speech recognition authorization.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Start listening and transcribing speech.
    func start() async throws {
        stopRecording()

        finalTranscript = ""
        lastSpeechDetectedTime = nil
        hasTriggeredSilence = false
        smoothingLevel = 0

        activeEngine = try resolveEngine()

        switch activeEngine {
        case .appleSpeech:
            try await startAppleSpeechRecognition()
        case .whisperCpp:
            try await startWhisperRecording()
        case .automatic:
            try await startWhisperRecording()
        }
    }

    /// Stop listening and return the final transcript.
    ///
    /// Apple Speech returns the latest partial/final transcript immediately.
    /// whisper.cpp records first, then transcribes the temporary WAV after stop.
    func stopAndTranscribe() async throws -> String {
        let audioURL = whisperAudioURL
        stopRecording()

        guard activeEngine == .whisperCpp, let audioURL else {
            return finalTranscript
        }

        defer {
            try? FileManager.default.removeItem(at: audioURL)
        }

        let transcript = try await transcribeWithWhisper(audioURL: audioURL)
        finalTranscript = transcript
        onPartialTranscript?(transcript)
        return transcript
    }

    /// Cancel any in-progress recording without running final transcription.
    func cancel() {
        stopRecording()
        finalTranscript = ""
    }

    // MARK: - Apple Speech

    private func startAppleSpeechRecognition() async throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        let micGranted = await requestMicrophoneAccess()
        guard micGranted else {
            throw SpeechRecognizerError.microphoneAccessDenied
        }

        let speechGranted = await requestAuthorization()
        guard speechGranted else {
            throw SpeechRecognizerError.authorizationDenied
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = [
            "Notch", "NotchAgent", "Agent", "Codex", "Cursor", "Anti Gravity",
            "Ollama", "OpenAI", "Apple Music", "Spotify", "GitHub", "Mail",
            "VSCode", "Xcode", "Omer", "Faruk", "Aras"
        ]

        if #available(macOS 13.0, *) {
            request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
        }

        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            self?.handleAudioLevel(buffer: buffer, requiresTranscriptForSilence: true)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, _ in
            Task { @MainActor in
                guard let self, let result else { return }

                let transcript = result.bestTranscription.formattedString
                self.finalTranscript = transcript
                self.onPartialTranscript?(transcript)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
    }

    // MARK: - whisper.cpp

    private func startWhisperRecording() async throws {
        let micGranted = await requestMicrophoneAccess()
        guard micGranted else {
            throw SpeechRecognizerError.microphoneAccessDenied
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("notchagent-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        let livePreviewRequest = await makeAppleLivePreviewRequest()

        whisperAudioFile = try AVAudioFile(forWriting: audioURL, settings: recordingFormat.settings)
        whisperAudioURL = audioURL
        recognitionRequest = livePreviewRequest

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            do {
                try self?.whisperAudioFile?.write(from: buffer)
            } catch {
                // The final transcription step will fail cleanly if no usable audio was written.
            }

            livePreviewRequest?.append(buffer)
            self?.handleAudioLevel(buffer: buffer, requiresTranscriptForSilence: false)
        }

        if let speechRecognizer, let livePreviewRequest {
            recognitionTask = speechRecognizer.recognitionTask(with: livePreviewRequest) { [weak self] result, _ in
                Task { @MainActor in
                    guard let self, let result else { return }

                    let transcript = result.bestTranscription.formattedString
                    self.finalTranscript = transcript
                    self.onPartialTranscript?(transcript)
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
    }

    private func makeAppleLivePreviewRequest() async -> SFSpeechAudioBufferRecognitionRequest? {
        guard let speechRecognizer, speechRecognizer.isAvailable else { return nil }

        let speechGranted = await requestAuthorization()
        guard speechGranted else { return nil }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = [
            "Notch", "NotchAgent", "Agent", "Codex", "Cursor", "Anti Gravity",
            "Ollama", "OpenAI", "Apple Music", "Spotify", "GitHub", "Mail",
            "VSCode", "Xcode", "Omer", "Faruk", "Aras"
        ]

        if #available(macOS 13.0, *) {
            request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
        }

        return request
    }

    private func transcribeWithWhisper(audioURL: URL) async throws -> String {
        let executableURL = try configuration.resolvedWhisperExecutableURL()
        let modelURL = try configuration.resolvedWhisperModelURL()

        return try await Task.detached(priority: .userInitiated) {
            try WhisperCppRunner.transcribe(
                executableURL: executableURL,
                modelURL: modelURL,
                audioURL: audioURL
            )
        }.value
    }

    private func resolveEngine() throws -> SpeechRecognitionEngine {
        switch configuration.engine {
        case .appleSpeech:
            return .appleSpeech
        case .whisperCpp:
            _ = try configuration.resolvedWhisperExecutableURL()
            _ = try configuration.resolvedWhisperModelURL()
            return .whisperCpp
        case .automatic:
            if configuration.hasUsableWhisperConfiguration {
                return .whisperCpp
            }
            return .appleSpeech
        }
    }

    // MARK: - Recording

    private func stopRecording() {
        recognitionRequest?.endAudio()

        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        whisperAudioFile = nil
        whisperAudioURL = nil

        isRunning = false
        smoothingLevel = 0
        onLevelChange?(0)
    }

    private nonisolated func handleAudioLevel(buffer: AVAudioPCMBuffer, requiresTranscriptForSilence: Bool) {
        let level = Self.rmsLevel(from: buffer)

        Task { @MainActor in
            self.smoothingLevel = (self.smoothingLevel * 0.6) + (level * 0.4)
            self.onLevelChange?(self.smoothingLevel)

            guard !self.hasTriggeredSilence else { return }

            if self.smoothingLevel > self.speechLevelThreshold {
                self.lastSpeechDetectedTime = Date()
            } else if let lastSpeech = self.lastSpeechDetectedTime,
                      (!requiresTranscriptForSilence || !self.finalTranscript.isEmpty),
                      Date().timeIntervalSince(lastSpeech) > self.silenceThresholdSeconds {
                self.hasTriggeredSilence = true
                self.onSilenceDetected?()
            }
        }
    }

    // MARK: - Audio Level

    nonisolated private static func rmsLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return 0 }

        var sum: Float = 0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for index in 0..<frameLength {
                let sample = samples[index]
                sum += sample * sample
            }
        }

        let mean = sum / Float(channelCount * frameLength)
        let rms = sqrt(mean)
        return min(max(Double(rms) * 9.0, 0), 1)
    }

    // MARK: - Microphone Access

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - Configuration

enum SpeechRecognitionEngine: String, CaseIterable, Identifiable {
    case automatic = "Auto"
    case appleSpeech = "Apple Speech"
    case whisperCpp = "Whisper.cpp"

    var id: String { rawValue }
}

struct SpeechRecognitionConfiguration {
    var engine: SpeechRecognitionEngine = .automatic
    var whisperExecutablePath = ""
    var whisperModelPath = ""

    var hasUsableWhisperConfiguration: Bool {
        (try? resolvedWhisperExecutableURL()) != nil && (try? resolvedWhisperModelURL()) != nil
    }

    func resolvedWhisperExecutableURL() throws -> URL {
        let bundledExecutablePaths = [
            Bundle.main.path(forResource: "whisper-cli", ofType: nil, inDirectory: "Whisper"),
            Bundle.main.path(forResource: "whisper-cpp", ofType: nil, inDirectory: "Whisper"),
            Bundle.main.path(forResource: "main", ofType: nil, inDirectory: "Whisper"),
            Bundle.main.path(forResource: "whisper-cli", ofType: nil),
            Bundle.main.path(forResource: "whisper-cpp", ofType: nil),
            Bundle.main.path(forResource: "main", ofType: nil)
        ].compactMap { $0 }

        let candidates = [whisperExecutablePath] + bundledExecutablePaths + Self.homebrewWhisperExecutablePaths
        let normalizedCandidates = candidates.compactMap { path -> String? in
            let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return nil }
            return NSString(string: path).expandingTildeInPath
        }

        let fileManager = FileManager.default
        let commonHomebrewPaths = Self.homebrewWhisperExecutablePaths.map {
            NSString(string: $0).expandingTildeInPath
        }
        let path = normalizedCandidates.first(where: {
            fileManager.isExecutableFile(atPath: $0) || fileManager.fileExists(atPath: $0)
        }) ?? commonHomebrewPaths.first(where: { $0.hasSuffix("/whisper-cli") })

        guard let path else { throw SpeechRecognizerError.whisperExecutableMissing }

        return URL(fileURLWithPath: path)
    }

    private static var homebrewWhisperExecutablePaths: [String] {
        [
            "/opt/homebrew/bin/whisper-cli",
            "/opt/homebrew/bin/whisper-cpp",
            "/opt/homebrew/bin/whisper",
            "/opt/homebrew/bin/main",
            "/opt/homebrew/opt/whisper-cpp/bin/whisper-cli",
            "/opt/homebrew/opt/whisper-cpp/bin/whisper-cpp",
            "/opt/homebrew/opt/whisper-cpp/bin/whisper",
            "/opt/homebrew/opt/whisper-cpp/bin/main",
            "/usr/local/bin/whisper-cli",
            "/usr/local/bin/whisper-cpp",
            "/usr/local/bin/whisper",
            "/usr/local/bin/main",
            "/usr/local/opt/whisper-cpp/bin/whisper-cli",
            "/usr/local/opt/whisper-cpp/bin/whisper-cpp",
            "/usr/local/opt/whisper-cpp/bin/whisper",
            "/usr/local/opt/whisper-cpp/bin/main"
        ]
    }

    func resolvedWhisperModelURL() throws -> URL {
        let bundledModelPaths = Bundle.main.urls(forResourcesWithExtension: "bin", subdirectory: "Whisper")?
            .map(\.path) ?? []

        let candidates = [
            whisperModelPath.trimmingCharacters(in: .whitespacesAndNewlines)
        ] + bundledModelPaths + Self.commonWhisperModelPaths

        guard let path = candidates
            .map({ NSString(string: $0).expandingTildeInPath })
            .first(where: { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) }) else {
            throw SpeechRecognizerError.whisperModelMissing
        }

        return URL(fileURLWithPath: path)
    }

    private static var commonWhisperModelPaths: [String] {
        [
            "~/Library/Application Support/NotchAgent/Whisper/ggml-small.bin",
            "~/Library/Application Support/NotchAgent/Whisper/ggml-base.bin",
            "~/Library/Application Support/NotchAgent/Whisper/ggml-tiny.bin",
            "/opt/homebrew/share/whisper-cpp/ggml-small.bin",
            "/opt/homebrew/share/whisper-cpp/ggml-base.bin",
            "/opt/homebrew/share/whisper-cpp/ggml-tiny.bin",
            "/usr/local/share/whisper-cpp/ggml-small.bin",
            "/usr/local/share/whisper-cpp/ggml-base.bin",
            "/usr/local/share/whisper-cpp/ggml-tiny.bin"
        ]
    }
}

enum WhisperCppRunner {
    nonisolated static func testExecutable(executableURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            executableURL.lastPathComponent,
            "--help"
        ]

        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let message = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            throw SpeechRecognizerError.whisperFailed(message.isEmpty ? "whisper-cli --help exited with code \(process.terminationStatus)" : message)
        }
    }

    nonisolated static func transcribe(executableURL: URL, modelURL: URL, audioURL: URL) throws -> String {
        let process = Process()
        let threadCount = max(4, min(ProcessInfo.processInfo.activeProcessorCount - 2, 10))
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            executableURL.lastPathComponent,
            "-m", modelURL.path,
            "-f", audioURL.path,
            "-l", "auto",
            "-t", "\(threadCount)",
            "-bo", "1",
            "-bs", "1",
            "-mc", "0",
            "-np",
            "-nt"
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            throw SpeechRecognizerError.whisperFailed(message.isEmpty ? "whisper.cpp exited with code \(process.terminationStatus)" : message)
        }

        let transcript = output
            .components(separatedBy: .newlines)
            .map { line in
                line.replacingOccurrences(of: #"^\s*\[[^\]]+\]\s*"#, with: "", options: .regularExpression)
            }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !transcript.isEmpty else {
            throw SpeechRecognizerError.whisperFailed("Whisper did not return any transcript")
        }

        return transcript
    }
}

// MARK: - Errors

enum SpeechRecognizerError: LocalizedError {
    case recognizerUnavailable
    case microphoneAccessDenied
    case authorizationDenied
    case whisperExecutableMissing
    case whisperModelMissing
    case whisperFailed(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            "Speech recognizer is not available on this device"
        case .microphoneAccessDenied:
            "Microphone access was denied"
        case .authorizationDenied:
            "Speech recognition authorization was denied"
        case .whisperExecutableMissing:
            "Whisper.cpp binary was not found"
        case .whisperModelMissing:
            "Whisper.cpp model was not found"
        case .whisperFailed(let message):
            "Whisper.cpp failed: \(message)"
        }
    }
}
