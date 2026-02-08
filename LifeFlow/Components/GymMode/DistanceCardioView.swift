//
//  DistanceCardioView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import SwiftUI

/// Distance-based cardio workout that counts up toward a target distance.
/// Designed for Marathon Coach integration to track running sessions.
struct DistanceCardioView: View {
    let exerciseName: String
    let targetDistance: Double  // Target in miles
    let onComplete: (Double, Double, Double, [CardioInterval]?, Bool) -> Void  // actualDistance, speed, incline, history, endedEarly
    let onCancel: () -> Void
    
    @Environment(GymModeManager.self) private var gymModeManager
    @Environment(HealthKitManager.self) private var healthKitManager
    
    @State private var phase: DistancePhase = .setup
    @State private var speed: Double = 5.0
    @State private var incline: Double = 0.0
    @State private var expandedSetting: CardioSetting? = nil
    
    enum CardioSetting {
        case speed
        case incline
    }
    
    @State private var currentDistance: Double = 0  // Distance covered in miles
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showCelebration: Bool = false
    @State private var showEndEarlyAlert: Bool = false
    
    // History tracking
    @State private var intervals: [CardioInterval] = []
    @State private var currentIntervalStart: Date = Date()
    
    enum DistancePhase {
        case setup
        case active
        case complete
    }
    
    var body: some View {
        ZStack {
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
        .alert("End Run Early?", isPresented: $showEndEarlyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Run", role: .destructive) {
                endWorkout(early: true)
            }
        } message: {
            Text("Are you sure you want to end your run early? Your \(String(format: "%.2f", currentDistance)) mi will be saved.")
        }
    }
    
    // MARK: - Setup View
    
    private var setupView: some View {
        VStack(spacing: 20) {
            // Speed and Incline (Standard compact boxes)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    CardioSettingBox(
                        label: "Speed",
                        value: speed,
                        unit: "mph",
                        color: .green,
                        isExpanded: expandedSetting == .speed,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                expandedSetting = expandedSetting == .speed ? nil : .speed
                            }
                        }
                    )
                    
                    CardioSettingBox(
                        label: "Incline",
                        value: incline,
                        unit: "%",
                        color: .orange,
                        isExpanded: expandedSetting == .incline,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                expandedSetting = expandedSetting == .incline ? nil : .incline
                            }
                        }
                    )
                }
                
                if let setting = expandedSetting {
                    CardioIncrementInput(
                        value: setting == .speed ? $speed : $incline,
                        unit: setting == .speed ? "mph" : "%",
                        color: setting == .speed ? .green : .orange,
                        increments: setting == .speed ? [0.1, 0.5, 1.0, 2.5] : [0.1, 0.5, 2.5, 5.0],
                        onValueChanged: { }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.top, 4)
            
            // Start button
            Button {
                startWorkout()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.title3)
                    Text("Start Guided Run")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Active View
    
    private var activeView: some View {
        VStack(spacing: 20) {
            // Progress ring with distance (Standard sizing)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                
                VStack(spacing: 2) {
                    Text(String(format: "%.2f", displayDistance))
                        .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    
                    Text("of \(String(format: "%.1f", targetDistance)) mi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
            
            // Elapsed and Pace
            HStack(spacing: 32) {
                VStack(spacing: 2) {
                    Text(formattedElapsedTime)
                        .font(.title3.weight(.bold).monospacedDigit())
                    Text("TIME")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 2) {
                    Text(formattedPace)
                        .font(.title3.weight(.bold).monospacedDigit())
                    Text("PACE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Speed and Incline (Active phase)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    CardioSettingBox(
                        label: "Speed",
                        value: speed,
                        unit: "mph",
                        color: .green,
                        isExpanded: expandedSetting == .speed,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                expandedSetting = expandedSetting == .speed ? nil : .speed
                            }
                        }
                    )
                    
                    CardioSettingBox(
                        label: "Incline",
                        value: incline,
                        unit: "%",
                        color: .orange,
                        isExpanded: expandedSetting == .incline,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                expandedSetting = expandedSetting == .incline ? nil : .incline
                            }
                        }
                    )
                }
                
                if let setting = expandedSetting {
                    CardioIncrementInput(
                        value: setting == .speed ? $speed : $incline,
                        unit: setting == .speed ? "mph" : "%",
                        color: setting == .speed ? .green : .orange,
                        increments: setting == .speed ? [0.1, 0.5, 1.0, 2.5] : [0.1, 0.5, 2.5, 5.0],
                        onValueChanged: {
                            // Sync with widget
                            gymModeManager.updateCardioState(
                                mode: 0,
                                endTime: Date().addingTimeInterval(remainingTimeFromPace),
                                speed: speed,
                                incline: incline,
                                elapsedTime: elapsedTime,
                                duration: targetDistance // Using distance as base
                            )
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // End early button
            Button {
                showEndEarlyAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                    Text("End Run Early")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
    
    private var remainingTimeFromPace: TimeInterval {
        guard currentDistance > 0 else { return 0 }
        let paceSeconds = elapsedTime / currentDistance
        return paceSeconds * remainingDistance
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
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 80))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .purple)
                    .scaleEffect(showCelebration ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCelebration)
                
                Text("Run Complete! 🏃‍♂️")
                    .font(.largeTitle.weight(.bold))
                    .opacity(showCelebration ? 1 : 0)
                    .animation(.easeIn.delay(0.3), value: showCelebration)
                
                VStack(spacing: 8) {
                    Text("You ran")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("\(String(format: "%.2f", currentDistance)) miles")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.purple)
                    
                    Text("in \(formattedElapsedTime)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                let finalIntervals = allIntervalsWithCurrent
                onComplete(currentDistance, speed, incline, finalIntervals, false)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var progress: Double {
        guard targetDistance > 0 else { return 0 }
        return min(1.0, currentDistance / targetDistance)
    }
    
    private var remainingDistance: Double {
        max(0, targetDistance - displayDistance)
    }
    
    private var displayDistance: Double {
        gymModeManager.healthKitDistance > 0 ? gymModeManager.healthKitDistance : currentDistance
    }
    
    private var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let mins = (Int(elapsedTime) % 3600) / 60
        let secs = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
    
    private var formattedPace: String {
        guard currentDistance > 0 else { return "--:-- /mi" }
        let paceSeconds = elapsedTime / currentDistance
        let mins = Int(paceSeconds) / 60
        let secs = Int(paceSeconds) % 60
        return String(format: "%d:%02d /mi", mins, secs)
    }
    
    private var allIntervalsWithCurrent: [CardioInterval] {
        let all = intervals
        var current = CardioInterval(speed: speed, incline: incline)
        current.duration = Date().timeIntervalSince(currentIntervalStart)
        return all + [current]
    }
    
    // MARK: - Actions
    
    private func startWorkout() {
        currentDistance = 0
        elapsedTime = 0
        phase = .active
        
        // Start live tracking if possible
        gymModeManager.startHealthKitRun(hkManager: healthKitManager)
        
        // Init history
        currentIntervalStart = Date()
        intervals = []
        
        // Start timer - update every second
        // Distance is simulated based on speed (mph converted to miles per second)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
            
            // Calculate distance traveled this second (speed mph -> miles per second)
            let distanceThisSecond = speed / 3600.0
            currentDistance += distanceThisSecond
            
            // Check if target reached
            if currentDistance >= targetDistance {
                timer?.invalidate()
                timer = nil
                phase = .complete
            }
        }
    }
    
    private func recordInterval(oldSpeed: Double, oldIncline: Double) {
        var interval = CardioInterval(speed: oldSpeed, incline: oldIncline)
        let duration = Date().timeIntervalSince(currentIntervalStart)
        interval.duration = duration
        
        if duration > 1 {
            intervals.append(interval)
        }
        
        currentIntervalStart = Date()
    }
    
    private func endWorkout(early: Bool) {
        timer?.invalidate()
        timer = nil
        
        let finalIntervals = allIntervalsWithCurrent
        onComplete(currentDistance, speed, incline, finalIntervals, early)
    }
}

// MARK: - Preview

#Preview("Distance Cardio - 3 miles") {
    DistanceCardioView(
        exerciseName: "Run",
        targetDistance: 3.0,
        onComplete: { distance, speed, incline, intervals, early in
            print("Completed: \(distance) mi")
        },
        onCancel: { }
    )
}

#Preview("Distance Cardio - 5K") {
    DistanceCardioView(
        exerciseName: "5K Run",
        targetDistance: 3.1,
        onComplete: { _, _, _, _, _ in },
        onCancel: { }
    )
}
