//
//  AudioLevelMonitor.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import AVFoundation
import Foundation

@MainActor
final class AudioLevelMonitor {
    private let engine = AVAudioEngine()
    private var smoothingLevel: Double = 0

    var isRunning: Bool {
        engine.isRunning
    }

    func start(onLevelChange: @escaping @MainActor (Double) -> Void) async throws {
        let isGranted = await requestMicrophoneAccess()
        guard isGranted else {
            throw AudioLevelMonitorError.microphoneAccessDenied
        }

        stop()

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            guard let self else { return }

            let level = Self.level(from: buffer)

            Task { @MainActor in
                self.smoothingLevel = (self.smoothingLevel * 0.62) + (level * 0.38)
                onLevelChange(self.smoothingLevel)
            }
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        guard engine.isRunning else {
            smoothingLevel = 0
            return
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        smoothingLevel = 0
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }

    private static func level(from buffer: AVAudioPCMBuffer) -> Double {
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
        let rootMeanSquare = sqrt(mean)
        return min(max(Double(rootMeanSquare) * 9.0, 0), 1)
    }
}

enum AudioLevelMonitorError: Error {
    case microphoneAccessDenied
}
