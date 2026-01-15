import SwiftUI

struct LiquidTimeInput: View {
    @Binding var duration: TimeInterval
    
    // Available increments
    let increments: [TimeInterval] = [30, 60, 300, 1800]
    @State private var selectedIncrement: TimeInterval = 60
    
    // Formatting for display
    var formattedTime: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // 1. Controls (Minus / Time / Plus)
            HStack(spacing: 16) {
                // Minus Button
                Button {
                    if duration >= selectedIncrement {
                        duration -= selectedIncrement
                    } else {
                        duration = 0
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 50, height: 50)
                        .background {
                            Circle()
                                .fill(.clear)
                                .glassEffect(.regular.interactive())
                        }
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        }
                }
                .buttonStyle(InteractingButtonStyle())
                
                // Time Display
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.numericText(value: duration))
                        .animation(.snappy, value: duration)
                    
                    Text(duration >= 3600 ? "hr" : "min")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 120)
                .fixedSize(horizontal: true, vertical: false)
                
                // Plus Button
                Button {
                    duration += selectedIncrement
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 50, height: 50)
                        .background {
                            Circle()
                                .fill(Color.green.opacity(0.8))
                                .glassEffect(.regular.interactive())
                        }
                        .clipShape(Circle())
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(InteractingButtonStyle())
            }
            
            // 2. Increment Selector
            Picker("Increment", selection: $selectedIncrement) {
                ForEach(increments, id: \.self) { value in
                    Text(formatIncrement(value)).tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 12)
    }
    
    private func formatIncrement(_ value: TimeInterval) -> String {
        if value < 60 {
            return "\(Int(value))s"
        } else {
            return "\(Int(value / 60))m"
        }
    }
}

// Helper Button Style
private struct InteractingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
