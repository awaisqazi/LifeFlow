//
//  ScrollWheelPicker.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

/// A custom wheel-style picker optimized for gym use.
/// Features large touch targets and haptic feedback for sweaty hands.
struct ScrollWheelPicker: View {
    @Binding var value: Double
    
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    
    @State private var isDragging: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Value display
            Text(formatValue(value))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: value)
            
            Text(unit)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            
            // Increment/Decrement buttons
            HStack(spacing: 16) {
                DecrementButton(value: $value, step: step, range: range)
                IncrementButton(value: $value, step: step, range: range)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
    
    private func formatValue(_ val: Double) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", val)
        } else {
            return String(format: "%.1f", val)
        }
    }
}

// MARK: - Increment Button

private struct IncrementButton: View {
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        Button {
            let newValue = min(value + step, range.upperBound)
            if newValue != value {
                value = newValue
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        } label: {
            Image(systemName: "plus")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(Color.green.gradient, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Decrement Button

private struct DecrementButton: View {
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        Button {
            let newValue = max(value - step, range.lowerBound)
            if newValue != value {
                value = newValue
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
        } label: {
            Image(systemName: "minus")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(Color.red.opacity(0.8).gradient, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScrollWheelPicker(
            value: .constant(135),
            range: 0...500,
            step: 5,
            unit: "lbs"
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
