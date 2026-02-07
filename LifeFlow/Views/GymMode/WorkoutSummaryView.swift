//
//  WorkoutSummaryView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import HealthKit

/// Post-workout summary with stats and HealthKit save option.
/// Tap exercises to see detailed set information.
struct GymWorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let session: WorkoutSession
    let onDone: () -> Void
    
    @State private var saveToHealthKit: Bool = true
    @State private var isSaving: Bool = false
    @State private var healthKitManager = HealthKitManager()
    @State private var expandedExerciseIDs: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Celebration header
                    celebrationHeader
                    
                    // Stats grid
                    statsGrid
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    // Exercise breakdown with expandable details
                    exerciseBreakdown
                    
                    // HealthKit toggle
                    healthKitSection
                    
                    Spacer(minLength: 80)
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Workout Complete")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                doneButton
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Celebration Header
    
    private var celebrationHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
            }
            
            Text("Great Work! 💪")
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(session.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(title: "Duration", value: formattedDuration, icon: "clock.fill", color: .blue)
            StatCard(title: "Exercises", value: "\(session.exercises.count)", icon: "dumbbell.fill", color: .orange)
            StatCard(title: "Sets", value: "\(totalCompletedSets)/\(totalSets)", icon: "repeat", color: .purple)
            StatCard(title: "Est. Calories", value: "\(estimatedCalories)", icon: "flame.fill", color: .red)
        }
    }
    
    // MARK: - Exercise Breakdown
    
    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EXERCISE BREAKDOWN")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                Spacer()
                
                Text("Tap to see details")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(session.sortedExercises, id: \.id) { exercise in
                    ExpandableExerciseCard(
                        exercise: exercise,
                        isExpanded: expandedExerciseIDs.contains(exercise.id),
                        onToggle: {
                            withAnimation(.spring(response: 0.3)) {
                                if expandedExerciseIDs.contains(exercise.id) {
                                    expandedExerciseIDs.remove(exercise.id)
                                } else {
                                    expandedExerciseIDs.insert(exercise.id)
                                }
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - HealthKit Section
    
    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPLE HEALTH")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save to Health")
                        .font(.subheadline.weight(.medium))
                    Text("Adds workout to Apple Health")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $saveToHealthKit)
                    .labelsHidden()
            }
            .padding(16)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
    }
    
    // MARK: - Done Button
    
    private var doneButton: some View {
        Button {
            completeWorkout()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                    Text("Done")
                        .font(.headline.weight(.bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.green.gradient, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Computed Properties
    
    private var formattedDuration: String {
        let hours = Int(session.duration) / 3600
        let minutes = (Int(session.duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var totalSets: Int {
        session.exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    private var totalCompletedSets: Int {
        session.exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }
    
    private var estimatedCalories: Int {
        let setsCalories = totalCompletedSets * 5
        let durationCalories = Int(session.duration / 60) * 3
        return setsCalories + durationCalories
    }
    
    // MARK: - Actions
    
    private func completeWorkout() {
        isSaving = true
        
        Task {
            session.calories = Double(estimatedCalories)
            
            if saveToHealthKit {
                // HealthKit save would go here
            }
            
            await MainActor.run {
                isSaving = false
                onDone()
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Expandable Exercise Card

private struct ExpandableExerciseCard: View {
    let exercise: WorkoutExercise
    let isExpanded: Bool
    let onToggle: () -> Void
    
    private var completedSets: [ExerciseSet] {
        exercise.sortedSets.filter(\.isCompleted)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header row (always visible)
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: exercise.type.icon)
                        .font(.callout)
                        .foregroundStyle(colorForType(exercise.type))
                        .frame(width: 32, height: 32)
                        .background(colorForType(exercise.type).opacity(0.15), in: Circle())
                    
                    // Name
                    Text(exercise.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // Best set badge
                    if let bestSet = bestSetString {
                        Text(bestSet)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15), in: Capsule())
                    }
                    
                    // Set count
                    Text("\(completedSets.count)/\(exercise.sets.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            
            // Expanded detail view
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                VStack(spacing: 8) {
                    ForEach(Array(exercise.sortedSets.enumerated()), id: \.element.id) { index, set in
                        SetDetailRow(setNumber: index + 1, set: set, exerciseType: exercise.type)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.02))
            }
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var bestSetString: String? {
        guard let best = completedSets.max(by: { ($0.weight ?? 0) * Double($0.reps ?? 0) < ($1.weight ?? 0) * Double($1.reps ?? 0) }),
              let weight = best.weight, let reps = best.reps else {
            return nil
        }
        return "\(Int(weight))×\(reps)"
    }
    
    private func colorForType(_ type: ExerciseType) -> Color {
        switch type {
        case .weight: return .orange
        case .cardio: return .green
        case .calisthenics: return .blue
        case .flexibility: return .purple
        case .machine: return .red
        case .functional: return .cyan
        }
    }
}

// MARK: - Set Detail Row

private struct SetDetailRow: View {
    let setNumber: Int
    let set: ExerciseSet
    let exerciseType: ExerciseType
    
    var body: some View {
        HStack(spacing: 12) {
            // Set number with completion indicator
            ZStack {
                Circle()
                    .fill(set.isCompleted ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                    .frame(width: 28, height: 28)
                
                if set.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                } else {
                    Text("\(setNumber)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("Set \(setNumber)")
                .font(.caption.weight(.medium))
                .foregroundStyle(set.isCompleted ? .primary : .secondary)
            
            Spacer()
            
            // Set details based on type
            if set.isCompleted {
                setDetails
            } else {
                Text("Not completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var setDetails: some View {
        switch exerciseType {
        case .weight, .machine, .functional:
            HStack(spacing: 8) {
                if let weight = set.weight {
                    Label("\(Int(weight)) lbs", systemImage: "scalemass.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
                
                if let reps = set.reps {
                    Label("\(reps) reps", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                }
            }
            
        case .cardio:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let duration = set.duration {
                        Label(formatDuration(duration), systemImage: "clock.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                    
                    if let speed = set.speed {
                        Label("\(speed, specifier: "%.1f") mph", systemImage: "speedometer")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.cyan)
                    }
                    
                    if set.wasEndedEarly {
                        Text("Ended Early")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.8), in: Capsule())
                    }
                }
                
                // Interval History
                if let data = set.cardioIntervals,
                   let intervals = try? JSONDecoder().decode([CardioInterval].self, from: data),
                   !intervals.isEmpty {
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pace History")
                           .font(.caption2.weight(.semibold))
                           .foregroundStyle(.secondary)
                        
                        FlowLayout(spacing: 4) {
                            ForEach(Array(intervals.enumerated()), id: \.offset) { index, interval in
                                Text("\(index + 1): \(String(format: "%.1f", interval.speed))mph")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.1), in: Capsule())
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
        case .calisthenics:
            if let reps = set.reps {
                Label("\(reps) reps", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
            }
            
        case .flexibility:
            if let duration = set.duration {
                Label(formatDuration(duration), systemImage: "timer")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.purple)
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }
}

#Preview {
    let session = WorkoutSession(title: "Push Day", type: "Strength Training")
    session.duration = 45 * 60
    
    // Add sample exercises
    let benchPress = WorkoutExercise(name: "Bench Press", type: .weight)
    let set1 = benchPress.addSet()
    set1.weight = 135
    set1.reps = 10
    set1.isCompleted = true
    let set2 = benchPress.addSet()
    set2.weight = 155
    set2.reps = 8
    set2.isCompleted = true
    let set3 = benchPress.addSet()
    set3.weight = 175
    set3.reps = 6
    set3.isCompleted = true
    session.exercises.append(benchPress)
    
    return GymWorkoutSummaryView(session: session, onDone: {})
}

// MARK: - Flow Layout Helper

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map { $0.width }.max() ?? 0
        let height = rows.map { $0.height }.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                let size = item.sizeThatFits(.unspecified)
                item.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentRow.width + size.width + spacing > maxWidth {
                rows.append(currentRow)
                currentRow = Row()
            }
            
            currentRow.add(item: subview, size: size, spacing: spacing)
        }
        
        if !currentRow.items.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    struct Row {
        var items: [LayoutSubview] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        mutating func add(item: LayoutSubview, size: CGSize, spacing: CGFloat) {
            if !items.isEmpty {
                width += spacing
            }
            items.append(item)
            width += size.width
            height = max(height, size.height)
        }
    }
}
