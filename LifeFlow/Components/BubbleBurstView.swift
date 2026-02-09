//
//  BubbleBurstView.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI

/// Lightweight celebratory particle burst tuned for LifeFlow's liquid aesthetic.
/// Trigger by incrementing `trigger`.
struct BubbleBurstView: View {
    var trigger: Int
    var tint: Color = .cyan
    var particleCount: Int = 22
    var spread: CGFloat = 140
    var rise: CGFloat = 190
    var duration: TimeInterval = 1.05
    
    @State private var progress: Double = 1
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<particleCount, id: \.self) { index in
                    bubble(index: index, in: geometry.size)
                }
            }
            .compositingGroup()
            .task(id: trigger) {
                await animateBurst()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private func bubble(index: Int, in size: CGSize) -> some View {
        let sizeSeed = seededValue(index: index, salt: 1)
        let driftSeed = seededSignedValue(index: index, salt: 2)
        let riseSeed = seededValue(index: index, salt: 3)
        let alphaSeed = seededValue(index: index, salt: 4)
        let startX = size.width * 0.5 + CGFloat(driftSeed * 12)
        let startY = size.height * 0.92
        let xDrift = CGFloat(driftSeed) * spread
        let yTravel = rise * CGFloat(0.65 + (riseSeed * 0.55))
        let particleSize = CGFloat(6 + (sizeSeed * 14))
        let opacity = max(0, (1 - progress) * (0.42 + (alphaSeed * 0.58)))
        
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.95),
                        tint.opacity(0.85),
                        tint.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: particleSize, height: particleSize)
            .position(
                x: startX + (xDrift * progress),
                y: startY - (yTravel * progress)
            )
            .scaleEffect(1 - (progress * 0.32))
            .opacity(opacity)
            .blur(radius: progress * 0.7)
    }
    
    @MainActor
    private func animateBurst() async {
        guard trigger > 0 else { return }
        
        progress = 0
        try? await Task.sleep(nanoseconds: 20_000_000)
        withAnimation(.easeOut(duration: duration)) {
            progress = 1
        }
    }
    
    private func seededValue(index: Int, salt: Int) -> Double {
        var hasher = Hasher()
        hasher.combine(trigger)
        hasher.combine(index)
        hasher.combine(salt)
        let value = UInt64(bitPattern: Int64(hasher.finalize()))
        return Double(value % 10_000) / 10_000
    }
    
    private func seededSignedValue(index: Int, salt: Int) -> Double {
        (seededValue(index: index, salt: salt) * 2) - 1
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        BubbleBurstView(trigger: 1, tint: .cyan)
            .frame(height: 260)
            .padding()
    }
}
