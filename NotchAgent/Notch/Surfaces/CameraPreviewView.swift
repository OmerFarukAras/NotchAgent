//
//  CameraPreviewView.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 15.06.2026.
//

import AVFoundation
import SwiftUI

struct CameraPreviewView: NSViewRepresentable {
    let selectedCameraID: String

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedCameraID: selectedCameraID)
    }

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView(session: context.coordinator.session)
        context.coordinator.start()
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {}

    final class Coordinator {
        let selectedCameraID: String
        let session = AVCaptureSession()
        private let queue = DispatchQueue(label: "notchagent.camera.preview")
        private var isConfigured = false

        init(selectedCameraID: String) {
            self.selectedCameraID = selectedCameraID
        }

        func start() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                configureAndStart()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard granted else { return }
                    self?.configureAndStart()
                }
            default:
                break
            }
        }

        private func configureAndStart() {
            queue.async { [weak self] in
                guard let self else { return }

                if !isConfigured {
                    session.beginConfiguration()
                    session.sessionPreset = .medium

                    var preferredDevice: AVCaptureDevice?
                    
                    if !self.selectedCameraID.isEmpty {
                        preferredDevice = AVCaptureDevice(uniqueID: self.selectedCameraID)
                    }
                    
                    if preferredDevice == nil {
                        let discoverySession = AVCaptureDevice.DiscoverySession(
                            deviceTypes: [.builtInWideAngleCamera],
                            mediaType: .video,
                            position: .unspecified
                        )
                        preferredDevice = discoverySession.devices.first { $0.isConnected } ?? AVCaptureDevice.default(for: .video)
                    }

                    if
                        let device = preferredDevice,
                        let input = try? AVCaptureDeviceInput(device: device),
                        session.canAddInput(input)
                    {
                        session.addInput(input)
                    }

                    session.commitConfiguration()
                    isConfigured = true
                }

                if !session.isRunning {
                    session.startRunning()
                }
            }
        }
    }
}

final class CameraPreviewNSView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds.insetBy(
            dx: -bounds.width * 0.08,
            dy: -bounds.height * 0.08
        )
        previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        previewLayer.connection?.isVideoMirrored = true
    }
}
