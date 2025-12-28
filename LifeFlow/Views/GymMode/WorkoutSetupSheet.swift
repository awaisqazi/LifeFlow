//
//  WorkoutSetupSheet.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import SwiftData

/// Pre-workout configuration sheet.
/// Allows selection of exercises, templates, and superset groupings.
struct WorkoutSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var workoutTitle: String = ""
    @State private var selectedExercises: [WorkoutExercise] = []
    @State private var showExercisePicker: Bool = false
    
    let onStart: (WorkoutSession) -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Workout title
                    titleSection
                    
                    // Quick templates
                    templatesSection
                    
                    // Selected exercises
                    if !selectedExercises.isEmpty {
                        selectedExercisesSection
                    }
                    
                    // Add exercise button
                    addExerciseButton
                    
                    Spacer(minLength: 100)
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                startButton
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { exercises in
                    selectedExercises.append(contentsOf: exercises)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORKOUT NAME")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            TextField("e.g. Push Day", text: $workoutTitle)
                .font(.title3.weight(.semibold))
                .padding(16)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Templates Section
    
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK START")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    TemplateButton(title: "Push Day", icon: "arrow.up.circle.fill", color: .orange) {
                        loadTemplate(.push)
                    }
                    TemplateButton(title: "Pull Day", icon: "arrow.down.circle.fill", color: .blue) {
                        loadTemplate(.pull)
                    }
                    TemplateButton(title: "Leg Day", icon: "figure.walk", color: .green) {
                        loadTemplate(.legs)
                    }
                    TemplateButton(title: "Full Body", icon: "figure.mixed.cardio", color: .purple) {
                        loadTemplate(.fullBody)
                    }
                }
            }
        }
    }
    
    // MARK: - Selected Exercises Section
    
    private var selectedExercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EXERCISES")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                Spacer()
                
                Text("\(selectedExercises.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange, in: Capsule())
            }
            
            VStack(spacing: 8) {
                ForEach(Array(selectedExercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseRow(
                        exercise: exercise,
                        onRemove: {
                            selectedExercises.remove(at: index)
                        },
                        onSetCountChange: { count in
                            // Add sets to the exercise
                            let currentCount = exercise.sets.count
                            if count > currentCount {
                                for _ in 0..<(count - currentCount) {
                                    _ = exercise.addSet()
                                }
                            } else if count < currentCount {
                                exercise.sets.removeLast(currentCount - count)
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Add Exercise Button
    
    private var addExerciseButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Add Exercise")
                    .font(.headline)
            }
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Start Button
    
    private var startButton: some View {
        Button {
            startWorkout()
        } label: {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                Text("Start Workout")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                selectedExercises.isEmpty
                    ? Color.gray.gradient
                    : Color.green.gradient,
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedExercises.isEmpty)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Actions
    
    private func startWorkout() {
        // Create workout session
        let session = WorkoutSession(
            title: workoutTitle.isEmpty ? "Workout" : workoutTitle,
            type: "Strength Training"
        )
        
        // Add exercises
        for (index, exercise) in selectedExercises.enumerated() {
            exercise.orderIndex = index
            exercise.session = session
            session.exercises.append(exercise)
        }
        
        // Insert into model context
        modelContext.insert(session)
        
        dismiss()
        onStart(session)
    }
    
    private func loadTemplate(_ template: WorkoutTemplate) {
        workoutTitle = template.title
        selectedExercises = template.exercises.map { name in
            let exercise = WorkoutExercise(name: name, type: .weight)
            // Add 3 default sets
            _ = exercise.addSet()
            _ = exercise.addSet()
            _ = exercise.addSet()
            return exercise
        }
    }
}

// MARK: - Template Button

private struct TemplateButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 90, height: 80)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Row

private struct ExerciseRow: View {
    let exercise: WorkoutExercise
    let onRemove: () -> Void
    let onSetCountChange: (Int) -> Void
    
    @State private var setCount: Int = 3
    
    var body: some View {
        HStack(spacing: 12) {
            // Drag handle (future: for reordering)
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
            
            // Exercise icon
            Image(systemName: exercise.type.icon)
                .font(.callout)
                .foregroundStyle(colorForType(exercise.type))
                .frame(width: 32, height: 32)
                .background(colorForType(exercise.type).opacity(0.15), in: Circle())
            
            // Exercise name
            Text(exercise.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Set count stepper
            HStack(spacing: 4) {
                Button {
                    if setCount > 1 {
                        setCount -= 1
                        onSetCountChange(setCount)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                
                Text("\(setCount)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .frame(width: 24)
                
                Button {
                    if setCount < 10 {
                        setCount += 1
                        onSetCountChange(setCount)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
                    .background(Color.red.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            setCount = max(exercise.sets.count, 1)
        }
    }
    
    private func colorForType(_ type: ExerciseType) -> Color {
        switch type {
        case .weight: return .orange
        case .cardio: return .green
        case .calisthenics: return .blue
        case .flexibility: return .purple
        }
    }
}

// MARK: - Workout Templates

private enum WorkoutTemplate {
    case push
    case pull
    case legs
    case fullBody
    
    var title: String {
        switch self {
        case .push: return "Push Day"
        case .pull: return "Pull Day"
        case .legs: return "Leg Day"
        case .fullBody: return "Full Body"
        }
    }
    
    var exercises: [String] {
        switch self {
        case .push:
            return ["Bench Press", "Overhead Press", "Dumbbell Fly", "Tricep Extension", "Push-ups"]
        case .pull:
            return ["Deadlift", "Barbell Row", "Pull-ups", "Lat Pulldown", "Dumbbell Curl"]
        case .legs:
            return ["Squat", "Leg Press", "Romanian Deadlift", "Leg Curl", "Calf Raise"]
        case .fullBody:
            return ["Squat", "Bench Press", "Deadlift", "Overhead Press", "Barbell Row"]
        }
    }
}

// MARK: - Exercise Picker Sheet

private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText: String = ""
    @State private var selectedType: ExerciseType? = nil
    @State private var selectedNames: Set<String> = []
    
    let onSelect: ([WorkoutExercise]) -> Void
    
    private var filteredExercises: [String] {
        let all: [String]
        switch selectedType {
        case .weight, .none:
            all = WorkoutExercise.weightExercises
        case .cardio:
            all = WorkoutExercise.cardioExercises
        case .calisthenics:
            all = WorkoutExercise.calisthenicsExercises
        case .flexibility:
            return ["Hamstring Stretch", "Quad Stretch", "Shoulder Stretch", "Hip Flexor Stretch"]
        }
        
        if searchText.isEmpty {
            return all
        } else {
            return all.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        TypeFilterChip(type: nil, selectedType: $selectedType, label: "All")
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            TypeFilterChip(type: type, selectedType: $selectedType, label: type.title)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                Divider()
                
                // Exercise list
                List {
                    ForEach(filteredExercises, id: \.self) { name in
                        Button {
                            if selectedNames.contains(name) {
                                selectedNames.remove(name)
                            } else {
                                selectedNames.insert(name)
                            }
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedNames.contains(name) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedNames.count))") {
                        let exercises = selectedNames.map { name in
                            let type = selectedType ?? .weight
                            let exercise = WorkoutExercise(name: name, type: type)
                            _ = exercise.addSet()
                            _ = exercise.addSet()
                            _ = exercise.addSet()
                            return exercise
                        }
                        onSelect(exercises)
                        dismiss()
                    }
                    .disabled(selectedNames.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct TypeFilterChip: View {
    let type: ExerciseType?
    @Binding var selectedType: ExerciseType?
    let label: String
    
    private var isSelected: Bool {
        type == selectedType
    }
    
    var body: some View {
        Button {
            selectedType = type
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.orange : Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkoutSetupSheet { _ in }
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
