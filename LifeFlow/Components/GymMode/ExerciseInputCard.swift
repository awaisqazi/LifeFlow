//
//  ExerciseInputCard.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

/// Two-phase input card for tracking sets.
/// Phase 1: Set weight → Start Set
/// Phase 2: Enter reps → Complete
struct ExerciseInputCard: View {
    let exercise: WorkoutExercise
    let setNumber: Int
    let previousData: (weight: Double?, reps: Int?)?
    
    @Binding var weight: Double
    @Binding var reps: Double
    @Binding var duration: TimeInterval
    @Binding var speed: Double
    @Binding var incline: Double
    
    let onComplete: () -> Void
    
    /// Phase of the set: setup (weight) or active (reps)
    @State private var phase: SetPhase = .setup
    
    /// Timer for active set
    @State private var setDuration: TimeInterval = 0
    @State private var setTimerActive: Bool = false
    
    enum SetPhase {
        case setup   // Enter weight, start set
        case active  // Doing set, enter reps when done
    }
    
    var body: some View {
        GlassCard(cornerRadius: 24) {
            VStack(spacing: 20) {
                // Header
                exerciseHeader
                
                // Progressive overload hint
                if let previous = previousData, let w = previous.weight, let r = previous.reps {
                    previousSessionHint(weight: w, reps: r)
                }
                
                // Phase-specific content
                switch exercise.type {
                case .weight, .calisthenics:
                    if phase == .setup {
                        setupPhaseView
                    } else {
                        activePhaseView
                    }
                case .cardio:
                    cardioInputs
                case .flexibility:
                    flexibilityInputs
                }
            }
            .padding(20)
        }
        .animation(.spring(response: 0.4), value: phase)
    }
    
    // MARK: - Header
    
    private var exerciseHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    Text("Set \(setNumber)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    if phase == .active && setTimerActive {
                        Text("•")
                            .foregroundStyle(.orange)
                        Text(formatDuration(setDuration))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Phase indicator
            if exercise.type == .weight || exercise.type == .calisthenics {
                PhaseIndicator(phase: phase)
            }
        }
    }
    
    // MARK: - Previous Session Hint
    
    private func previousSessionHint(weight: Double, reps: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
            
            Text("Last: \(Int(weight)) lbs × \(reps)")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05), in: Capsule())
    }
    
    // MARK: - Setup Phase (Weight)
    
    private var setupPhaseView: some View {
        VStack(spacing: 24) {
            // Weight input (or just reps for calisthenics)
            if exercise.type == .weight {
                VStack(spacing: 12) {
                    Text("WEIGHT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    CompactInput(
                        value: $weight,
                        unit: "lbs",
                        color: .orange,
                        quickAdd: [5, 10, 25]
                    )
                }
            } else {
                // Calisthenics - no weight needed
                Text("Ready for \(exercise.name)?")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            // Start Set button
            Button {
                startSet()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.title3)
                    Text("Start Set")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Active Phase (Reps)
    
    private var activePhaseView: some View {
        VStack(spacing: 24) {
            // Show weight being used (if applicable)
            if exercise.type == .weight && weight > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "scalemass.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("\(Int(weight)) lbs")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.15), in: Capsule())
            }
            
            // Reps input
            VStack(spacing: 12) {
                Text("REPS COMPLETED")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                CompactInput(
                    value: $reps,
                    unit: "",
                    color: .green,
                    quickAdd: [1, 5, 10]
                )
            }
            
            // Complete Set button
            Button {
                completeSet()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Complete Set")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            
            // Cancel / go back
            Button {
                phase = .setup
                setTimerActive = false
            } label: {
                Text("Change Weight")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Cardio Inputs (single phase)
    
    private var cardioInputs: some View {
        VStack(spacing: 20) {
            // Duration
            MinuteSecondInput(duration: $duration, label: "Duration")
            
            HStack(spacing: 12) {
                MiniInput(value: $speed, label: "Speed", unit: "mph", color: .green)
                MiniInput(value: $incline, label: "Incline", unit: "%", color: .green)
            }
            
            // Complete button
            Button {
                onComplete()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Complete")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Flexibility Inputs
    
    private var flexibilityInputs: some View {
        VStack(spacing: 20) {
            MinuteSecondInput(duration: $duration, label: "Hold Duration")
            
            Button {
                onComplete()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Complete")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.purple.gradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Actions
    
    private func startSet() {
        phase = .active
        setDuration = 0
        setTimerActive = true
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Start timer
        startSetTimer()
    }
    
    private func completeSet() {
        setTimerActive = false
        phase = .setup  // Reset for next set
        onComplete()
    }
    
    private func startSetTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if setTimerActive {
                setDuration += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Phase Indicator

private struct PhaseIndicator: View {
    let phase: ExerciseInputCard.SetPhase
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(phase == .setup ? Color.orange : Color.white.opacity(0.3))
                .frame(width: 8, height: 8)
            
            Circle()
                .fill(phase == .active ? Color.green : Color.white.opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05), in: Capsule())
    }
}

// MARK: - Compact Input

private struct CompactInput: View {
    @Binding var value: Double
    let unit: String
    let color: Color
    let quickAdd: [Double]
    
    var body: some View {
        VStack(spacing: 16) {
            // Main value with +/- controls
            HStack(spacing: 24) {
                // Minus button
                Button {
                    if value >= 1 { value -= 1 }
                    triggerHaptic()
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(color.opacity(0.8))
                        .frame(width: 50, height: 50)
                        .background(color.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                
                // Value display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formattedValue)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: value)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 100)
                
                // Plus button
                Button {
                    value += 1
                    triggerHaptic()
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(color, in: Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Quick add pills
            HStack(spacing: 8) {
                ForEach(quickAdd, id: \.self) { amount in
                    Button {
                        value += amount
                        let impact = UIImpactFeedbackGenerator(style: .soft)
                        impact.impactOccurred()
                    } label: {
                        Text("+\(formatAmount(amount))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(color.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var formattedValue: String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        } else {
            return String(format: "%.1f", amount)
        }
    }
    
    private func triggerHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Mini Input

private struct MiniInput: View {
    @Binding var value: Double
    let label: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                Button {
                    if value >= 0.5 { value -= 0.5 }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                
                Text("\(value, specifier: "%.1f")")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .frame(minWidth: 40)
                
                Button {
                    value += 0.5
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.2), in: Circle())
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
            }
            
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Minute/Second Input

private struct MinuteSecondInput: View {
    @Binding var duration: TimeInterval
    let label: String
    
    private var minutes: Int { Int(duration) / 60 }
    private var seconds: Int { Int(duration) % 60 }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                StepperValue(value: minutes, onMinus: { if minutes > 0 { duration -= 60 } }, onPlus: { duration += 60 })
                Text(":").font(.title3.weight(.bold))
                StepperValue(value: seconds, format: "%02d", onMinus: { if duration >= 15 { duration -= 15 } }, onPlus: { duration += 15 })
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct StepperValue: View {
    let value: Int
    var format: String = "%d"
    let onMinus: () -> Void
    let onPlus: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: onMinus) {
                Image(systemName: "minus")
                    .font(.caption2.weight(.bold))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            
            Text(String(format: format, value))
                .font(.title3.weight(.bold).monospacedDigit())
                .frame(minWidth: 28)
            
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.caption2.weight(.bold))
                    .frame(width: 28, height: 28)
                    .background(Color.green.opacity(0.2), in: Circle())
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        let exercise = WorkoutExercise(name: "Bench Press", type: .weight)
        
        ExerciseInputCard(
            exercise: exercise,
            setNumber: 1,
            previousData: (weight: 135, reps: 8),
            weight: .constant(135),
            reps: .constant(0),
            duration: .constant(0),
            speed: .constant(0),
            incline: .constant(0),
            onComplete: {}
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
