//
//  GhostCursorManager.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 19.06.2026.
//

import SwiftUI
import AppKit

@MainActor
final class GhostCursorManager {
    static let shared = GhostCursorManager()
    
    private var overlayWindow: NSWindow?
    private var hostingView: NSHostingView<GhostCursorView>?
    
    private init() {}
    
    func show(at point: CGPoint, message: String) {
        if overlayWindow == nil {
            let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            let window = NSWindow(
                contentRect: screenRect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let cursorView = GhostCursorView(targetPoint: point, message: message)
            let host = NSHostingView(rootView: cursorView)
            window.contentView = host
            
            self.overlayWindow = window
            self.hostingView = host
            window.makeKeyAndOrderFront(nil)
        } else {
            hostingView?.rootView = GhostCursorView(targetPoint: point, message: message)
        }
        
        // Auto-hide after 4 seconds
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            hide()
        }
    }
    
    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        hostingView = nil
    }
}

struct GhostCursorView: View {
    let targetPoint: CGPoint
    let message: String
    
    @State private var position: CGPoint
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 2.0
    
    init(targetPoint: CGPoint, message: String) {
        self.targetPoint = targetPoint
        self.message = message
        
        // Start from center of screen roughly
        let screen = NSScreen.main?.frame ?? .zero
        self._position = State(initialValue: CGPoint(x: screen.width / 2, y: screen.height / 2))
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // The ghost cursor
                AgentEyesView(state: .listening)
                    .shadow(color: .accentColor.opacity(0.8), radius: 10)
                    .scaleEffect(scale)
                    .position(x: position.x, y: position.y)
                
                // The message
                Text(message)
                    .font(.headline)
                    .padding(8)
                    .background(.thinMaterial)
                    .cornerRadius(8)
                    .position(
                        x: max(150, min(geo.size.width - 150, position.x)),
                        y: position.y - 40
                    )
            }
            .opacity(opacity)
            .onAppear {
                // Animate entrance and movement
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 1.0
                    scale = 1.0
                }
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                    position = targetPoint
                }
                
                // Pulse animation
                withAnimation(.easeInOut(duration: 0.5).repeatForever().delay(0.8)) {
                    scale = 1.2
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
