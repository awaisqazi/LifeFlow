//
//  SlideToStartControl.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI

struct SlideToStartControl: View {
    var title: String = "Slide to Start"
    var tint: Color = .green
    var completionThreshold: Double = 0.85
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var hasCompleted = false

    var body: some View {
        GeometryReader { geometry in
            let knobSize: CGFloat = 52
            let trackPadding: CGFloat = 4
            let maxOffset = max(0, geometry.size.width - knobSize - (trackPadding * 2))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                HStack {
                    Spacer()
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(labelOpacity(maxOffset: maxOffset)))
                    Spacer()
                }

                Circle()
                    .fill(tint.gradient)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Image(systemName: "chevron.right.2")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    )
                    .offset(x: trackPadding + dragOffset)
                    .shadow(color: tint.opacity(0.45), radius: 10)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24))
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        guard !hasCompleted else { return }
                        dragOffset = min(max(0, value.translation.width), maxOffset)
                    }
                    .onEnded { _ in
                        guard !hasCompleted else { return }
                        let completion = maxOffset > 0 ? dragOffset / maxOffset : 0
                        if completion >= completionThreshold {
                            hasCompleted = true
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                dragOffset = maxOffset
                            }
                            let feedback = UINotificationFeedbackGenerator()
                            feedback.notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                onComplete()
                            }
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .frame(height: 60)
    }

    private func labelOpacity(maxOffset: CGFloat) -> Double {
        guard maxOffset > 0 else { return 1 }
        let progress = min(max(Double(dragOffset / maxOffset), 0), 1)
        return max(0.25, 1 - progress)
    }
}
