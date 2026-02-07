//
//  FreestyleCardioView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 1/10/26.
//

import SwiftUI

/// Freestyle cardio workout with live interval tracking
struct FreestyleCardioView: View {
    let exerciseName: String
    let onComplete: (TimeInterval, Double, Double, [CardioInterval]) -> Void  // duration, avgSpeed, avgIncline, intervals
    let onCancel: () -> Void
    
    @State private var phase: FreestylePhase = .countdown
    @State private var countdownValue: Int = 5
    @State private var elapsedTime: TimeInterval = 0
    @State private var speed: Double = 3.0
    @State private var incline: Double = 0.0
    @State private var intervals: [CardioInterval] = []
    @State private var currentIntervalStart: Date = Date()
    
    @State private var timer: Timer?
    @State private var showSummary: Bool = false
    @State private var showEndWorkoutAlert: Bool = false
    
    enum FreestylePhase {
        case countdown
        case active
        case summary
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch phase {
            case .countdown:
                countdownView
            case .active:
                activeView
            case .summary:
                summaryView
            }
        }
        .preferredColorScheme(.dark)
        .alert("End Workout?", isPresented: $showEndWorkoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Workout", role: .destructive) {
                endWorkout()
            }
        } message: {
            Text("Are you sure you want to end your freestyle workout?")
        }
    }
    
    // MARK: - Countdown View
    
    private var countdownView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Get Ready!")
                .font(.title.weight(.bold))
                .foregroundStyle(.secondary)
            
            Text("\(countdownValue)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())
            
            Text(exerciseName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button("Cancel", action: onCancel)
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)
        }
        .onAppear {
            startCountdown()
        }
    }
    
    // MARK: - Active View
    
    private var activeView: some View {
        VStack(spacing: 24) {
            // Header with elapsed time
            VStack(spacing: 4) {
                Text("WORKOUT TIME")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                Text(formattedElapsedTime)
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.green)
            }
            .padding(.top, 40)
            
            // Current interval indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .opacity(elapsedTime.truncatingRemainder(dividingBy: 2) < 1 ? 1 : 0.3)
                
                Text("Recording")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Speed and Incline controls
            VStack(spacing: 20) {
                LiveSettingControl(
                    label: "Speed",
                    value: $speed,
                    unit: "mph",
                    color: .green,
                    step: 0.5,
                    range: 0.5...12.0,
                    onChange: { recordIntervalChange() }
                )
                
                LiveSettingControl(
                    label: "Incline",
                    value: $incline,
                    unit: "%",
                    color: .orange,
                    step: 0.5,
                    range: 0...15.0,
                    onChange: { recordIntervalChange() }
                )
            }
            .padding(.horizontal)
            
            // Interval count
            Text("\(intervals.count + 1) intervals recorded")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // End workout button
            Button {
                showEndWorkoutAlert = true
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                    Text("End Workout")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    
    // MARK: - Summary View
    
    private var summaryView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                
                Text("Workout Complete!")
                    .font(.title.weight(.bold))
                
                Text(exerciseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            
            // Stats grid
            HStack(spacing: 16) {
                StatBox(label: "Total Time", value: formattedElapsedTime, color: .green)
                StatBox(label: "Avg Speed", value: String(format: "%.1f mph", averageSpeed), color: .cyan)
                StatBox(label: "Avg Incline", value: String(format: "%.1f%%", averageIncline), color: .orange)
            }
            .padding(.horizontal)
            
            // Interval breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("INTERVAL BREAKDOWN")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(allIntervalsWithCurrent.enumerated()), id: \.element.id) { index, interval in
                            IntervalRow(
                                index: index + 1,
                                interval: interval,
                                startTime: intervalStartTime(for: index)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 200)
            }
            
            Spacer()
            
            // Complete button
            Button {
                let finalIntervals = allIntervalsWithCurrent
                onComplete(elapsedTime, averageSpeed, averageIncline, finalIntervals)
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Complete Workout")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedElapsedTime: String {
        let mins = Int(elapsedTime) / 60
        let secs = Int(elapsedTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private var allIntervalsWithCurrent: [CardioInterval] {
        let all = intervals
        // Add current interval
        var current = CardioInterval(speed: speed, incline: incline)
        current.duration = Date().timeIntervalSince(currentIntervalStart)
        return all + [current]
    }
    
    private var averageSpeed: Double {
        let intervalsToAverage = allIntervalsWithCurrent
        guard !intervalsToAverage.isEmpty else { return 0 }
        
        var totalWeightedSpeed: Double = 0
        var totalDuration: TimeInterval = 0
        
        for interval in intervalsToAverage {
            let duration = interval.duration ?? 0
            totalWeightedSpeed += interval.speed * duration
            totalDuration += duration
        }
        
        return totalDuration > 0 ? totalWeightedSpeed / totalDuration : 0
    }
    
    private var averageIncline: Double {
        let intervalsToAverage = allIntervalsWithCurrent
        guard !intervalsToAverage.isEmpty else { return 0 }
        
        var totalWeightedIncline: Double = 0
        var totalDuration: TimeInterval = 0
        
        for interval in intervalsToAverage {
            let duration = interval.duration ?? 0
            totalWeightedIncline += interval.incline * duration
            totalDuration += duration
        }
        
        return totalDuration > 0 ? totalWeightedIncline / totalDuration : 0
    }
    
    private func intervalStartTime(for index: Int) -> String {
        var cumulativeTime: TimeInterval = 0
        for i in 0..<index {
            cumulativeTime += intervals[i].duration ?? 0
        }
        let mins = Int(cumulativeTime) / 60
        let secs = Int(cumulativeTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    // MARK: - Actions
    
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            withAnimation(.spring) {
                countdownValue -= 1
            }
            
            if countdownValue == 0 {
                timer.invalidate()
                startWorkout()
            }
        }
    }
    
    private func startWorkout() {
        phase = .active
        currentIntervalStart = Date()
        
        // Start elapsed time timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
        
        // Record initial interval
        intervals = []
    }
    
    private func recordIntervalChange() {
        // Complete the current interval
        var currentInterval = CardioInterval(speed: speed, incline: incline)
        currentInterval.duration = Date().timeIntervalSince(currentIntervalStart)
        
        // Only record if duration > 1 second
        if let duration = currentInterval.duration, duration > 1 {
            // Update the speed/incline of the PREVIOUS interval, not the new one
            if let last = intervals.popLast() {
                var updated = last
                updated.duration = Date().timeIntervalSince(currentIntervalStart)
                intervals.append(updated)
            } else {
                // First interval
                var first = CardioInterval(speed: speed, incline: incline)
                first.duration = Date().timeIntervalSince(currentIntervalStart)
                // Store with OLD values before change
            }
        }
        
        // Start new interval
        currentIntervalStart = Date()
        let newInterval = CardioInterval(speed: speed, incline: incline)
        intervals.append(newInterval)
    }
    
    private func endWorkout() {
        timer?.invalidate()
        timer = nil
        
        // Haptic feedback
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        
        phase = .summary
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
    let onChange: () -> Void
    
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
                        onChange()
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
                        onChange()
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

private struct StatBox: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct IntervalRow: View {
    let index: Int
    let interval: CardioInterval
    let startTime: String
    
    private var formattedDuration: String {
        guard let duration = interval.duration else { return "--" }
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
    
    var body: some View {
        HStack {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.1), in: Circle())
            
            Text(startTime)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 12) {
                Label(String(format: "%.1f mph", interval.speed), systemImage: "speedometer")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Label(String(format: "%.1f%%", interval.incline), systemImage: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            Text(formattedDuration)
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    FreestyleCardioView(
        exerciseName: "Treadmill",
        onComplete: { _, _, _, _ in },
        onCancel: { }
    )
}
