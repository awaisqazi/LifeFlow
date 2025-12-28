//
//  QuickIncrementStepper.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

/// Large stepper buttons for rapid weight/rep adjustments.
/// Designed for easy use with sweaty hands during workouts.
struct QuickIncrementStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let increments: [Double]
    let unit: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Value display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatValue(value))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
                
                Text(unit)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            // Increment row
            HStack(spacing: 8) {
                ForEach(increments, id: \.self) { increment in
                    IncrementPill(
                        value: $value,
                        increment: increment,
                        range: range,
                        isPositive: true
                    )
                }
            }
            
            // Decrement row
            HStack(spacing: 8) {
                ForEach(increments, id: \.self) { increment in
                    IncrementPill(
                        value: $value,
                        increment: -increment,
                        range: range,
                        isPositive: false
                    )
                }
            }
        }
        .padding(16)
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

// MARK: - Increment Pill Button

private struct IncrementPill: View {
    @Binding var value: Double
    let increment: Double
    let range: ClosedRange<Double>
    let isPositive: Bool
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button {
            let newValue = max(min(value + increment, range.upperBound), range.lowerBound)
            if newValue != value {
                value = newValue
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        } label: {
            Text(formatIncrement)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .background(backgroundColor.gradient, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
    }
    
    private var formatIncrement: String {
        let absValue = abs(increment)
        let formatted = absValue.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", absValue)
            : String(format: "%.1f", absValue)
        return isPositive ? "+\(formatted)" : "-\(formatted)"
    }
    
    private var backgroundColor: Color {
        isPositive ? .green : .red.opacity(0.8)
    }
}

// MARK: - Weight Stepper Preset

extension QuickIncrementStepper {
    /// Preset for weight input (lbs)
    static func forWeight(value: Binding<Double>) -> QuickIncrementStepper {
        QuickIncrementStepper(
            value: value,
            range: 0...1000,
            increments: [2.5, 5, 10],
            unit: "lbs"
        )
    }
    
    /// Preset for reps input
    static func forReps(value: Binding<Double>) -> QuickIncrementStepper {
        QuickIncrementStepper(
            value: value,
            range: 0...100,
            increments: [1, 5, 10],
            unit: "reps"
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            QuickIncrementStepper.forWeight(value: .constant(135))
            QuickIncrementStepper.forReps(value: .constant(8))
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
