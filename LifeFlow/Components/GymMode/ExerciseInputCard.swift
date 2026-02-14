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
    @Environment(\.gymModeManager) private var manager
    
    let exercise: WorkoutExercise
    let setNumber: Int
    let previousData: (weight: Double?, reps: Int?)?
    
    @Binding var weight: Double
    @Binding var reps: Double
    @Binding var duration: TimeInterval
    @Binding var distance: Double
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
        let content = VStack(spacing: 20) {
            // Header (hidden during immersive guided run)
            if !isGuidedRunInProgress {
                exerciseHeader
            }
            
            // Progressive overload hint (Hide for guided runs)
            if !isGuidedRunActive {
                if let previous = previousData, let w = previous.weight, let r = previous.reps {
                    previousSessionHint(weight: w, reps: r)
                }
            }
            
            // Phase-specific content
            switch exercise.type {
            case .weight, .calisthenics, .machine, .functional:
                if phase == .setup {
                    setupPhaseView
                } else {
                    activePhaseView
                }
            case .cardio:
                if case .distance(let miles, _) = manager.activeTarget {
                    DistanceCardioView(
                        exerciseName: exercise.name,
                        targetDistance: miles,
                        onComplete: { actualDistance, finalSpeed, finalIncline, history, early in
                            // Update state for save
                            self.distance = actualDistance
                            self.speed = finalSpeed
                            self.incline = finalIncline
                            self.duration = history?.reduce(0) { $0 + ($1.duration ?? 0) } ?? 0
                            
                            // Call complete through manager flow
                            self.onComplete()
                        },
                        onCancel: {
                            // Default to manual inputs if cancelled/skipped
                            self.cardioMode = .timed
                        }
                    )
                } else {
                    cardioInputs
                }
            case .flexibility:
                flexibilityInputs
            }
        }
        
        // When a guided run is in progress (active/complete phase),
        // skip the card wrapper so it can go edge-to-edge
        if isGuidedRunInProgress {
            content
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: phase)
        } else {
            content
                .padding(20)
                .liquidGlassCard()
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: phase)
        }
    }
    
    private var isGuidedRunActive: Bool {
        if case .distance = manager.activeTarget { return true }
        return false
    }
    
    /// True when a guided distance run is actively running (not in setup).
    private var isGuidedRunInProgress: Bool {
        isGuidedRunActive && manager.isCardioInProgress
    }
    
    // MARK: - Header
    
    private var exerciseHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    if isGuidedRunActive {
                        Text("Guided Run")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .foregroundStyle(.purple)
                        
                        Text("\(String(format: "%.1f", manager.targetDistance)) mi")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.purple)
                    } else {
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
            // Weight input (for weight, machine, and functional exercises)
            if exercise.type == .weight || exercise.type == .machine || exercise.type == .functional {
                VStack(spacing: 12) {
                    Text("WEIGHT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    CompactInput(
                        value: $weight,
                        unit: "lbs",
                        color: .orange,
                        increments: [1, 2.5, 5, 10, 25]
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
        VStack(spacing: 20) {
            // Show weight being used (if applicable)
            if (exercise.type == .weight || exercise.type == .machine || exercise.type == .functional) && weight > 0 {
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
            
            // Instructional message
            VStack(spacing: 4) {
                Text("Do your set now!")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Log your reps when finished")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            
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
                    increments: [1, 5, 10]
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
    
    // MARK: - Cardio Inputs (Timed or Freestyle)
    
    @State private var cardioMode: CardioWorkoutMode = .timed
    @State private var isCardioActive: Bool = false
    @State private var cardioElapsedTime: TimeInterval = 0
    @State private var cardioTimer: Timer?
    @State private var intervalDebounceTimer: Timer?
    @State private var lastRecordedSpeed: Double = 0
    @State private var lastRecordedIncline: Double = 0
    @State private var expandedSetting: CardioSetting? = nil
    // Old duration state removed
    
    private enum CardioSetting {
        case speed
        case incline
    }
    
    private var cardioInputs: some View {
        VStack(spacing: 16) {
            // Mode picker (only show if not active)
            if !isCardioActive {
                Picker("Mode", selection: $cardioMode) {
                    Text("Timed").tag(CardioWorkoutMode.timed)
                    Text("Freestyle").tag(CardioWorkoutMode.freestyle)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 4)
            }
            
            // Mode-specific content
            if cardioMode == .timed {
                timedCardioContent
            } else {
                freestyleCardioContent
            }
        }
    }
    
    // MARK: - Quick Add Time Buttons
    

    
    // MARK: - Quick Add Time Buttons
    
    private var quickAddTimeButtons: some View {
        HStack(spacing: 8) {
            ForEach([30, 60, 300, 900], id: \.self) { seconds in
                Button {
                    duration += TimeInterval(seconds)
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                } label: {
                    Text(quickAddLabel(seconds))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func quickAddLabel(_ seconds: Int) -> String {
        switch seconds {
        case 30: return "+30s"
        case 60: return "+1m"
        case 300: return "+5m"
        case 900: return "+15m"
        default: return "+\(seconds)s"
        }
    }
    
    // MARK: - Speed/Incline Box Components
    
    private var speedInclineInputs: some View {
        VStack(spacing: 12) {
            // Display boxes
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
            
            // Expanded increment control
            if let setting = expandedSetting {
                CardioIncrementInput(
                    value: setting == .speed ? $speed : $incline,
                    unit: setting == .speed ? "mph" : "%",
                    color: setting == .speed ? .green : .orange,
                    increments: setting == .speed ? [0.1, 0.5, 1.0, 2.5] : [0.1, 0.5, 2.5, 5.0],
                    onValueChanged: {
                        // Log interval changes for both timed and freestyle modes
                        if isCardioActive {
                            scheduleIntervalUpdate()
                            
                            // Sync with widget
                            let endTime = cardioMode == .timed ? Date().addingTimeInterval(duration - cardioElapsedTime) : nil
                            manager.updateCardioState(
                                mode: cardioMode == .timed ? 0 : 1,
                                endTime: endTime,
                                speed: speed,
                                incline: incline,
                                elapsedTime: cardioElapsedTime,
                                duration: duration
                            )
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private var timedCardioContent: some View {
        VStack(spacing: 16) {
            if isCardioActive {
                // Active: show countdown
                VStack(spacing: 8) {
                    Text(formatDuration(max(0, duration - cardioElapsedTime)))
                        .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(duration - cardioElapsedTime <= 10 ? .orange : .green)
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(Color.green.gradient)
                                .frame(width: geometry.size.width * (duration > 0 ? cardioElapsedTime / duration : 0), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.vertical, 8)
                
                // Quick add time buttons
                quickAddTimeButtons
                
                // Interactive Speed/Incline controls (can adjust during timed workout)
                speedInclineInputs
                
                // End Early button
                Button {
                    stopCardioWorkout()
                    onComplete()
                } label: {
                    Text("End Early")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                // Setup: duration and settings
                LiquidTimeInput(duration: $duration)
                
                speedInclineInputs
                
                // Start button
                Button {
                    startTimedCardio()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                        Text("Start Workout")
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
    }
    
    private var freestyleCardioContent: some View {
        VStack(spacing: 16) {
            if isCardioActive {
                // Active: show elapsed time
                VStack(spacing: 8) {
                    Text(formatDuration(cardioElapsedTime))
                        .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.green)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Recording")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                
                // Adjustable Speed/Incline with expandable inputs
                speedInclineInputs
                
                // End Workout button
                Button {
                    stopCardioWorkout()
                    duration = cardioElapsedTime // Save total time
                    onComplete()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                        Text("End Workout")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else {
                // Setup: initial speed/incline
                speedInclineInputs
                
                // Start button
                Button {
                    startFreestyleCardio()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                        Text("Start Workout")
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
    }
    
    private func startTimedCardio() {
        isCardioActive = true
        cardioElapsedTime = 0
        expandedSetting = nil
        lastRecordedIncline = incline
        
        // Sync with widget
        let endTime = Date().addingTimeInterval(duration)
        manager.updateCardioState(
            mode: 0,
            endTime: endTime,
            speed: speed,
            incline: incline,
            elapsedTime: 0,
            duration: duration
        )
        
        // Mark cardio as in progress
        manager.isCardioInProgress = true
        
        cardioTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard !manager.isPaused else { return }
            cardioElapsedTime += 1
            
            // Sync with widget every 5 seconds or on significant events
            if Int(cardioElapsedTime) % 5 == 0 {
                let remaining = max(0, duration - cardioElapsedTime)
                manager.updateCardioState(
                    mode: 0,
                    endTime: Date().addingTimeInterval(remaining),
                    speed: speed,
                    incline: incline,
                    elapsedTime: cardioElapsedTime,
                    duration: duration
                )
            }
            
            if cardioElapsedTime >= duration {
                // Auto-complete when timer finishes
                stopCardioWorkout()
                
                // Success haptic
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
                
                onComplete()
            }
        }
    }
    
    private func startFreestyleCardio() {
        isCardioActive = true
        cardioElapsedTime = 0
        expandedSetting = nil
        lastRecordedSpeed = speed
        lastRecordedIncline = incline
        
        // Sync with widget
        manager.updateCardioState(
            mode: 1,
            endTime: nil as Date?,
            speed: speed,
            incline: incline,
            elapsedTime: 0,
            duration: 0
        )
        
        // Mark cardio as in progress
        manager.isCardioInProgress = true
        
        cardioTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard !manager.isPaused else { return }
            cardioElapsedTime += 1
            
            // Sync with widget every 5 seconds
            if Int(cardioElapsedTime) % 5 == 0 {
                manager.updateCardioState(
                    mode: 1,
                    endTime: nil as Date?,
                    speed: speed,
                    incline: incline,
                    elapsedTime: cardioElapsedTime,
                    duration: 0
                )
            }
        }
    }
    
    /// Debounce interval updates - only record after 3 seconds of no changes
    private func scheduleIntervalUpdate() {
        intervalDebounceTimer?.invalidate()
        intervalDebounceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            // Only record if values actually changed
            if speed != lastRecordedSpeed || incline != lastRecordedIncline {
                lastRecordedSpeed = speed
                lastRecordedIncline = incline
                // Interval recorded (data already in speed/incline bindings)
            }
        }
    }
    
    private func stopCardioWorkout() {
        cardioTimer?.invalidate()
        cardioTimer = nil
        intervalDebounceTimer?.invalidate()
        intervalDebounceTimer = nil
        isCardioActive = false
        manager.isCardioInProgress = false
        
        // Clear widget cardio state
        manager.updateCardioState(mode: 0, endTime: nil as Date?, speed: 0, incline: 0, elapsedTime: 0, duration: 0)
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
            if setTimerActive && !manager.isPaused {
                setDuration += 1
            } else if !setTimerActive {
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
    let increments: [Double]
    
    @State private var selectedIncrement: Double
    
    init(value: Binding<Double>, unit: String, color: Color, increments: [Double]) {
        self._value = value
        self.unit = unit
        self.color = color
        self.increments = increments
        // Initialize with the middle-ish increment or first available
        self._selectedIncrement = State(initialValue: increments.count > 1 ? increments[1] : (increments.first ?? 1))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Main value with +/- controls
            HStack(spacing: 28) {
                // Minus button
                Button {
                    if value >= selectedIncrement {
                        value -= selectedIncrement
                    } else {
                        value = 0
                    }
                    triggerHaptic(.light)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(color)
                        .frame(width: 54, height: 54)
                        .contentShape(Circle())
                        .background {
                            Circle()
                                .fill(color.opacity(0.2))
                        }
                        .overlay {
                            Circle()
                                .stroke(color.opacity(0.4), lineWidth: 1)
                        }
                }
                .buttonStyle(InteractingButtonStyle())
                
                // Value display
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formattedValue)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: value)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 120)
                
                // Plus button
                Button {
                    value += selectedIncrement
                    triggerHaptic(.medium)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 54, height: 54)
                        .contentShape(Circle())
                        .background {
                            Circle()
                                .fill(color.gradient)
                        }
                        .clipShape(Circle())
                        .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(InteractingButtonStyle())
            }
            
            // Increment Selector (Native Segmented style)
            Picker("Increment", selection: $selectedIncrement) {
                ForEach(increments, id: \.self) { amount in
                    Text(formatAmount(amount)).tag(amount)
                }
            }
            .pickerStyle(.segmented)
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
            return String(format: "%.1f", amount).replacingOccurrences(of: ".0", with: "")
        } else {
            return String(format: "%.1f", amount)
        }
    }
    
    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impact = UIImpactFeedbackGenerator(style: style)
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
// MARK: - Interaction Styles

private struct InteractingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
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
            distance: .constant(0),
            speed: .constant(0),
            incline: .constant(0),
            onComplete: {}
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
