//
//  WorkoutSetupSheet.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import SwiftData

/// Pre-workout configuration sheet.
/// Shows favorite routines first, then quick templates.
struct WorkoutSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \WorkoutRoutine.createdAt, order: .reverse) private var savedRoutines: [WorkoutRoutine]
    
    @State private var workoutTitle: String = ""
    @State private var selectedExercises: [WorkoutExercise] = []
    @State private var showExercisePicker: Bool = false
    @State private var draggedExercise: WorkoutExercise?
    @State private var showSaveRoutineSheet: Bool = false
    
    let onStart: (WorkoutSession) -> Void
    
    /// Favorite routines sorted first
    private var sortedRoutines: [WorkoutRoutine] {
        savedRoutines.sorted { a, b in
            if a.isFavorite == b.isFavorite {
                return (a.lastUsedAt ?? a.createdAt) > (b.lastUsedAt ?? b.createdAt)
            }
            return a.isFavorite && !b.isFavorite
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView(currentTab: .temple)
                    .ignoresSafeArea()
                
                List {
                    // Workout title
                    Section {
                        titleSection
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
                    
                    // Favorites section (if any)
                    if !sortedRoutines.filter({ $0.isFavorite }).isEmpty {
                        Section {
                            favoritesSection
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 24, trailing: 20))
                        .listRowSeparator(.hidden)
                    }
                    
                    // Quick templates (built-in + saved)
                    Section {
                        templatesSection
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 24, trailing: 20))
                    .listRowSeparator(.hidden)
                    
                    // Selected exercises
                    if !selectedExercises.isEmpty {
                        Section {
                            ForEach(selectedExercises) { exercise in
                                ExerciseRow(
                                    exercise: exercise,
                                    onRemove: {
                                        if let index = selectedExercises.firstIndex(where: { $0.id == exercise.id }) {
                                            selectedExercises.remove(at: index)
                                        }
                                    },
                                    onSetCountChange: { count in
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
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                .listRowSeparator(.hidden)
                            }
                            .onMove { indices, newOffset in
                                selectedExercises.move(fromOffsets: indices, toOffset: newOffset)
                            }
                        } header: {
                            exerciseHeader
                        }
                        .environment(\.editMode, .constant(.active))
                    }
                    
                    // Add exercise button
                    Section {
                        addExerciseButton
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 100, trailing: 20))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
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
            .sheet(isPresented: $showSaveRoutineSheet) {
                SaveRoutineSheet(exercises: selectedExercises, workoutTitle: workoutTitle)
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
    
    // MARK: - Favorites Section
    
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text("FAVORITES")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sortedRoutines.filter { $0.isFavorite }) { routine in
                        SavedRoutineButton(routine: routine) {
                            loadRoutine(routine)
                        } onToggleFavorite: {
                            routine.isFavorite.toggle()
                            try? modelContext.save()
                        } onDelete: {
                            modelContext.delete(routine)
                            try? modelContext.save()
                        }
                    }
                }
            }
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
                    // Saved routines (non-favorites)
                    ForEach(sortedRoutines.filter { !$0.isFavorite }) { routine in
                        SavedRoutineButton(routine: routine) {
                            loadRoutine(routine)
                        } onToggleFavorite: {
                            routine.isFavorite.toggle()
                            try? modelContext.save()
                        } onDelete: {
                            modelContext.delete(routine)
                            try? modelContext.save()
                        }
                    }
                    
                    // Built-in templates
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
    
    private var exerciseHeader: some View {
        HStack {
            Text("EXERCISES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            Spacer()
            
            // Save as routine button
            Button {
                showSaveRoutineSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                    Text("Save")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15), in: Capsule())
            }
            
            Text("\(selectedExercises.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange, in: Capsule())
        }
        .padding(.top, 10)
        .padding(.horizontal, 20)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .textCase(nil)
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
        let session = WorkoutSession(
            title: workoutTitle.isEmpty ? "Workout" : workoutTitle,
            type: "Strength Training"
        )
        
        for (index, exercise) in selectedExercises.enumerated() {
            exercise.orderIndex = index
            exercise.session = session
            session.exercises.append(exercise)
        }
        
        modelContext.insert(session)
        
        dismiss()
        onStart(session)
    }
    
    private func loadTemplate(_ template: WorkoutTemplate) {
        workoutTitle = template.title
        selectedExercises = template.exercises.map { name in
            let exercise = WorkoutExercise(name: name, type: .weight)
            _ = exercise.addSet()
            _ = exercise.addSet()
            _ = exercise.addSet()
            return exercise
        }
    }
    
    private func loadRoutine(_ routine: WorkoutRoutine) {
        workoutTitle = routine.name
        selectedExercises = routine.exercises.map { routineExercise in
            let exercise = WorkoutExercise(name: routineExercise.name, type: routineExercise.exerciseType)
            for _ in 0..<routineExercise.setCount {
                _ = exercise.addSet()
            }
            return exercise
        }
        
        // Update last used
        routine.lastUsedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Saved Routine Button

private struct SavedRoutineButton: View {
    let routine: WorkoutRoutine
    let onTap: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    
    @State private var showActions: Bool = false
    
    private var color: Color {
        switch routine.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "red": return .red
        case "cyan": return .cyan
        default: return .orange
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: routine.icon)
                        .font(.title2)
                        .foregroundStyle(color)
                    
                    if routine.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                            .offset(x: 8, y: -4)
                    }
                }
                
                Text(routine.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(width: 90, height: 80)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onToggleFavorite()
            } label: {
                Label(routine.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: routine.isFavorite ? "star.slash" : "star.fill")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
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

// MARK: - Save Routine Sheet

private struct SaveRoutineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let exercises: [WorkoutExercise]
    let workoutTitle: String
    
    @State private var routineName: String = ""
    @State private var selectedIcon: String = "dumbbell.fill"
    @State private var selectedColor: String = "orange"
    @State private var isFavorite: Bool = false
    
    private let icons = ["dumbbell.fill", "figure.strengthtraining.traditional", "figure.run", "flame.fill", "bolt.fill", "heart.fill"]
    private let colors = ["orange", "blue", "green", "purple", "red", "cyan"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("ROUTINE NAME")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    TextField("e.g. My Push Day", text: $routineName)
                        .font(.title3.weight(.semibold))
                        .padding(16)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
                
                // Icon picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("ICON")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    HStack(spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(selectedIcon == icon ? .white : .secondary)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.orange : Color.white.opacity(0.1), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Color picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("COLOR")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { colorName in
                            let color = colorFromName(colorName)
                            Button {
                                selectedColor = colorName
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if selectedColor == colorName {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Favorite toggle
                Toggle(isOn: $isFavorite) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Add to Favorites")
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                
                // Exercise preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("EXERCISES (\(exercises.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    Text(exercises.map { $0.name }.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(20)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Save Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRoutine() }
                        .disabled(routineName.isEmpty)
                }
            }
            .onAppear {
                routineName = workoutTitle.isEmpty ? "" : workoutTitle
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveRoutine() {
        let routineExercises = exercises.map { exercise in
            RoutineExercise(name: exercise.name, type: exercise.type, setCount: exercise.sets.count)
        }
        
        let routine = WorkoutRoutine(
            name: routineName,
            icon: selectedIcon,
            color: selectedColor,
            exercises: routineExercises
        )
        routine.isFavorite = isFavorite
        
        modelContext.insert(routine)
        try? modelContext.save()
        
        dismiss()
    }
    
    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "red": return .red
        case "cyan": return .cyan
        default: return .orange
        }
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
            Image(systemName: "line.3.horizontal")
                .font(.subheadline)
                .foregroundStyle(.secondary.opacity(0.6))
            
            Image(systemName: exercise.type.icon)
                .font(.callout)
                .foregroundStyle(colorForType(exercise.type))
                .frame(width: 32, height: 32)
                .background(colorForType(exercise.type).opacity(0.15), in: Circle())
            
            Text(exercise.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            
            Spacer()
            
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
        case .machine: return .red
        case .functional: return .cyan
        }
    }
}

// MARK: - Workout Templates

private enum WorkoutTemplate {
    case push, pull, legs, fullBody
    
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
        case .none:
            all = WorkoutExercise.allExercises
        case .weight:
            all = WorkoutExercise.weightExercises
        case .cardio:
            all = WorkoutExercise.cardioExercises
        case .calisthenics:
            all = WorkoutExercise.calisthenicsExercises
        case .flexibility:
            all = WorkoutExercise.flexibilityExercises
        case .machine:
            all = WorkoutExercise.machineExercises
        case .functional:
            all = WorkoutExercise.functionalExercises
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedNames.count))") {
                        let exercises = selectedNames.map { name in
                            // Use the correct type for each exercise based on which category it belongs to
                            let type = selectedType ?? WorkoutExercise.exerciseType(for: name)
                            let exercise = WorkoutExercise(name: name, type: type)
                            // Cardio and flexibility get 1 set, others get 3
                            let setCount = (type == .cardio || type == .flexibility) ? 1 : 3
                            for _ in 0..<setCount {
                                _ = exercise.addSet()
                            }
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
    
    private var isSelected: Bool { type == selectedType }
    
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
        .modelContainer(for: [WorkoutSession.self, WorkoutRoutine.self], inMemory: true)
}
