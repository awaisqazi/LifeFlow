//
//  CardioUIComponents.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import SwiftUI

// MARK: - Cardio Setting Box (Tappable)

struct CardioSettingBox: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Edit Indicator
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(color.opacity(0.8))
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isExpanded ? color : color.opacity(0.3), lineWidth: isExpanded ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cardio Increment Input (Expandable)

struct CardioIncrementInput: View {
    @Binding var value: Double
    let unit: String
    let color: Color
    let increments: [Double]
    let onValueChanged: () -> Void
    
    @State private var selectedIncrement: Double
    
    init(value: Binding<Double>, unit: String, color: Color, increments: [Double], onValueChanged: @escaping () -> Void) {
        self._value = value
        self.unit = unit
        self.color = color
        self.increments = increments
        self.onValueChanged = onValueChanged
        // Initialize with second increment or first
        self._selectedIncrement = State(initialValue: increments.count > 1 ? increments[1] : (increments.first ?? 0.5))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Main controls with +/-
            HStack(spacing: 24) {
                // Minus button
                Button {
                    if value >= selectedIncrement {
                        value -= selectedIncrement
                    } else {
                        value = 0
                    }
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onValueChanged()
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(color.opacity(0.8))
                        .frame(width: 54, height: 54)
                        .background {
                            if #available(iOS 26.0, *) {
                                Circle()
                                    .fill(.clear)
                                    .glassEffect(.regular.interactive())
                            } else {
                                Circle()
                                    .fill(.ultraThinMaterial)
                            }
                        }
                        .overlay {
                            Circle()
                                .stroke(color.opacity(0.2), lineWidth: 1)
                        }
                }
                .buttonStyle(InteractingButtonStyle())
                
                // Value display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: value)
                    
                    Text(unit)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 90)
                
                // Plus button
                Button {
                    value += selectedIncrement
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    onValueChanged()
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 54, height: 54)
                        .background {
                            if #available(iOS 26.0, *) {
                                Circle()
                                    .fill(color.opacity(0.5))
                                    .glassEffect(.regular.interactive())
                            } else {
                                Circle()
                                    .fill(color.gradient)
                            }
                        }
                        .clipShape(Circle())
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(InteractingButtonStyle())
            }
            
            // Increment selector (Segmented style)
            Picker("Increment", selection: $selectedIncrement) {
                ForEach(increments, id: \.self) { amount in
                    Text(formatIncrement(amount)).tag(amount)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedIncrement) {
                let selection = UISelectionFeedbackGenerator()
                selection.selectionChanged()
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatIncrement(_ increment: Double) -> String {
        if increment == Double(Int(increment)) {
            return String(format: "%.0f", increment)
        } else {
            return String(format: "%.1f", increment)
        }
    }
}

private struct InteractingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
