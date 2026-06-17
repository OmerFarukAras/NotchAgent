//
//  AgentEyesView.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 17.06.2026.
//

import SwiftUI
import Combine

struct AgentEyesView: View {
    let state: NotchState
    
    @State private var blinkScale: CGFloat = 1.0
    @State private var lookOffset: CGSize = .zero
    @State private var eyeSpacing: CGFloat = 10
    
    let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: eyeSpacing) {
            Capsule()
                .fill(Design.Colors.stateColor(for: state))
                .frame(width: 6, height: 10)
                .scaleEffect(y: blinkScale)
                .offset(lookOffset)
            
            Capsule()
                .fill(Design.Colors.stateColor(for: state))
                .frame(width: 6, height: 10)
                .scaleEffect(y: blinkScale)
                .offset(lookOffset)
        }
        .frame(width: 40, height: 40)
        .background(Design.Colors.controlBackgroundActive, in: Circle())
        .onChange(of: state) { oldValue, newValue in
            updateAnimationState(for: newValue)
        }
        .onReceive(timer) { _ in
            triggerRandomMicroAnimations()
        }
        .onAppear {
            updateAnimationState(for: state)
        }
    }
    
    private func updateAnimationState(for currentState: NotchState) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            switch currentState {
            case .idle:
                lookOffset = .zero
                eyeSpacing = 10
            case .listening:
                // Eyes wider, focused
                lookOffset = .zero
                eyeSpacing = 14
            case .thinking:
                // Eyes looking up right
                lookOffset = CGSize(width: 4, height: -4)
                eyeSpacing = 10
            case .action, .result, .confirmation:
                // Eyes look slightly down
                lookOffset = CGSize(width: 0, height: 2)
                eyeSpacing = 10
            case .error:
                lookOffset = .zero
                eyeSpacing = 16
            }
        }
    }
    
    private func triggerRandomMicroAnimations() {
        // Random blinking
        if Double.random(in: 0...1) > 0.4 {
            blink()
        }
        
        // Random looking around if idle
        if state == .idle && Double.random(in: 0...1) > 0.7 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                lookOffset = CGSize(width: CGFloat.random(in: -3...3), height: CGFloat.random(in: -2...2))
            }
            
            // Return to center
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if state == .idle {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        lookOffset = .zero
                    }
                }
            }
        }
    }
    
    private func blink() {
        withAnimation(.easeIn(duration: 0.1)) {
            blinkScale = 0.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.1)) {
                blinkScale = 1.0
            }
        }
    }
}
