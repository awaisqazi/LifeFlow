//
//  TimedCardioView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 1/10/26.
//

import SwiftUI

/// Timed cardio workout with countdown timer and celebration
struct TimedCardioView: View {
    let exerciseName: String
    let onComplete: (TimeInterval, Double, Double, [CardioInterval]?, Bool) -> Void  // duration, speed, incline, history, endedEarly
    let onCancel: () -> Void
    
    @State private var phase: TimedPhase = .setup
    @State private var targetDuration: TimeInterval = 10 * 60  // 10 min default
    @State private var speed: Double = 3.0
    @State private var incline: Double = 0.0
    
    @State private var remainingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showCelebration: Bool = false
    @State private var showEndEarlyAlert: Bool = false
    
    // History tracking
    @State private var intervals: [CardioInterval] = []
    @State private var currentIntervalStart: Date = Date()
    
    enum TimedPhase {
        case setup
        case active
        case complete
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch phase {
            case .setup:
                setupView
            case .active:
                activeView
            case .complete:
                celebrationView
            }
        }
        .preferredColorScheme(.dark)
        .alert("End Session Early?", isPresented: $showEndEarlyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Session", role: .destructive) {
                endWorkout(early: true)
            }
        } message: {
            Text("Are you sure you want to end your timed workout early? Your progress will be saved.")
        }
    }
    
    // MARK: - Setup View
    
    private var setupView: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 48))
                    .foregroundStyle(.cyan)
                
                Text("Timed \(exerciseName)")
                    .font(.title2.weight(.bold))
                
                Text("Set your workout parameters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            
            // Duration input
            VStack(alignment: .leading, spacing: 8) {
                Text("DURATION")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                LiquidTimeInput(duration: $targetDuration)
            }
            
            // Speed and Incline
            HStack(spacing: 16) {
                SettingInput(
                    label: "Speed",
                    value: $speed,
                    unit: "mph",
                    color: .green,
                    step: 0.5,
                    range: 0.5...12.0
                )
                
                SettingInput(
                    label: "Incline",
                    value: $incline,
                    unit: "%",
                    color: .orange,
                    step: 0.5,
                    range: 0...15.0
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Start button
            Button {
                startWorkout()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.title3)
                    Text("Start \(Int(targetDuration / 60)) min Workout")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.cyan.gradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            // Cancel button
            Button("Cancel", action: onCancel)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
    }
    
    // MARK: - Active View
    
    private var activeView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Progress ring with time
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 240, height: 240)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                
                // Time display
                VStack(spacing: 4) {
                    Text(formattedRemainingTime)
                        .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Current settings
            HStack(spacing: 16) {
                 LiveSettingControl(
                     label: "Speed",
                     value: $speed,
                     unit: "mph",
                     color: .green,
                     step: 0.5,
                     range: 0.5...12.0
                 )
                 
                 LiveSettingControl(
                     label: "Incline",
                     value: $incline,
                     unit: "%",
                     color: .orange,
                     step: 0.5,
                     range: 0...15.0
                 )
             }
             .padding(.horizontal)
            
            Spacer()
            
            // End early button
            Button {
                showEndEarlyAlert = true
            } label: {
                Text("End Early")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
        .onChange(of: speed) { oldValue, newValue in
            recordInterval(oldSpeed: oldValue, oldIncline: incline)
        }
        .onChange(of: incline) { oldValue, newValue in
            recordInterval(oldSpeed: speed, oldIncline: oldValue)
        }
    }
    
    // MARK: - Celebration View
    
    private var celebrationView: some View {
        ZStack {
            // Confetti background
            if showCelebration {
                CelebrationParticles()
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 24) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)
                    .scaleEffect(showCelebration ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCelebration)
                
                Text("Great Job! 🎉")
                    .font(.largeTitle.weight(.bold))
                    .opacity(showCelebration ? 1 : 0)
                    .animation(.easeIn.delay(0.3), value: showCelebration)
                
                VStack(spacing: 8) {
                    Text("You completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("\(Int(targetDuration / 60)) minutes")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.cyan)
                }
                .opacity(showCelebration ? 1 : 0)
                .animation(.easeIn.delay(0.5), value: showCelebration)
            }
        }
        .onAppear {
            withAnimation {
                showCelebration = true
            }
            
            // Haptic feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            
            // Auto-complete after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                // Compile final intervals
                let finalIntervals = allIntervalsWithCurrent
                onComplete(targetDuration, speed, incline, finalIntervals, false)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var progress: Double {
        guard targetDuration > 0 else { return 0 }
        return 1 - (remainingTime / targetDuration)
    }
    
    private var formattedRemainingTime: String {
        let mins = Int(remainingTime) / 60
        let secs = Int(remainingTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private var allIntervalsWithCurrent: [CardioInterval] {
        let all = intervals
        // Add current interval
        var current = CardioInterval(speed: speed, incline: incline)
        current.duration = Date().timeIntervalSince(currentIntervalStart) 
        return all + [current]
    }
    
    // MARK: - Actions
    
    private func startWorkout() {
        remainingTime = targetDuration
        phase = .active
        
        // Init history
        currentIntervalStart = Date()
        intervals = []
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                timer?.invalidate()
                timer = nil
                phase = .complete
            }
        }
    }
    
    private func recordInterval(oldSpeed: Double, oldIncline: Double) {
        // The interval that JUST FINISHED used the OLD values.
        var interval = CardioInterval(speed: oldSpeed, incline: oldIncline)
        
        // Calculate duration since last change
        let duration = Date().timeIntervalSince(currentIntervalStart)
        interval.duration = duration
        
        // Only record meaningful intervals (> 1s) to avoid jitter
        if duration > 1 {
            intervals.append(interval)
        }
        
        // Reset start time for the NEW interval (which starts NOW with NEW values)
        currentIntervalStart = Date()
    }
    
    private func endWorkout(early: Bool) {
        timer?.invalidate()
        timer = nil
        
        let actualDuration = targetDuration - remainingTime
        let finalIntervals = allIntervalsWithCurrent
        
        // Capture final stats
        onComplete(actualDuration, speed, incline, finalIntervals, early)
    }
}

// MARK: - Supporting Views

private struct LiveSettingControl: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let color: Color
    let step: Double
    let range: ClosedRange<Double>
    var onChange: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button {
                    if value > range.lowerBound {
                        value = max(range.lowerBound, value - step)
                        onChange?()
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(color)
                        .frame(width: 50, height: 50)
                        .background(color.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 0) {
                    Text(String(format: "%.1f", value))
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 80)
                
                Button {
                    if value < range.upperBound {
                        value = min(range.upperBound, value + step)
                        onChange?()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(color.gradient, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct DurationChip: View {
    let minutes: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text("\(minutes)m")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSelected ? Color.cyan : Color.white.opacity(0.1),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct SettingInput: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let color: Color
    let step: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(spacing: 12) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            HStack(spacing: 16) {
                Button {
                    if value > range.lowerBound {
                        value = max(range.lowerBound, value - step)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(color)
                        .frame(width: 44, height: 44)
                        .background(color.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", value))
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 60)
                
                Button {
                    if value < range.upperBound {
                        value = min(range.upperBound, value + step)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(color.gradient, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SettingDisplay: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: Capsule())
    }
}

// MARK: - Celebration Particles

private struct CelebrationParticles: View {
    @State private var particles: [Particle] = []
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let color: Color
        let size: CGFloat
        var velocity: CGPoint
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.green, .cyan, .yellow, .orange, .pink, .purple]
        
        for _ in 0..<50 {
            let particle = Particle(
                x: size.width / 2,
                y: size.height / 2,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 6...14),
                velocity: CGPoint(
                    x: CGFloat.random(in: -8 ... 8),
                    y: CGFloat.random(in: -15 ... -5)
                )
            )
            particles.append(particle)
        }
        
        // Animate particles
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            for i in particles.indices {
                particles[i].x += particles[i].velocity.x
                particles[i].y += particles[i].velocity.y
                particles[i].velocity.y += 0.3 // gravity
            }
            
            // Remove off-screen particles
            particles.removeAll { $0.y > UIScreen.main.bounds.height + 50 }
            
            if particles.isEmpty {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    TimedCardioView(
        exerciseName: "Treadmill",
        onComplete: { _, _, _, _, _ in },
        onCancel: { }
    )
}
