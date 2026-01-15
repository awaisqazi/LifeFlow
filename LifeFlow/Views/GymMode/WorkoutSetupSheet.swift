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
        VStack(alignment: .leading, spacing: 10) {
            Text("WORKOUT NAME")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            TextField("e.g. Push Day", text: $workoutTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        }
                }
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
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Add Exercise")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.green.opacity(0.4), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // Button animation style
    private struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
        }
    }
    
    // MARK: - Start Button
    
    private var startButton: some View {
        Button {
            startWorkout()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                Text("Start Workout")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                selectedExercises.isEmpty
                    ? Color.gray.gradient
                    : Color.green.gradient,
                in: RoundedRectangle(cornerRadius: 20)
            )
            .shadow(color: selectedExercises.isEmpty ? .clear : .green.opacity(0.3), radius: 12, x: 0, y: 6)
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
            VStack(spacing: 10) {
                // Icon with colored ring
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.4), lineWidth: 2)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: routine.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                    
                    // Favorite badge
                    if routine.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                            .offset(x: 16, y: -16)
                    }
                }
                
                Text(routine.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            .frame(width: 95, height: 90)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
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
            VStack(spacing: 10) {
                // Icon with colored ring
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.4), lineWidth: 2)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            .frame(width: 95, height: 90)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    }
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
    
    private var exerciseColor: Color {
        switch exercise.type {
        case .weight: return .orange
        case .cardio: return .green
        case .calisthenics: return .blue
        case .flexibility: return .purple
        case .machine: return .red
        case .functional: return .cyan
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon with colored ring
            ZStack {
                Circle()
                    .stroke(exerciseColor.opacity(0.4), lineWidth: 2)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .fill(exerciseColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: exercise.type.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(exerciseColor)
            }
            
            // Exercise info
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                
                Text(exercise.type.title)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            
            Spacer()
            
            // Set counter
            HStack(spacing: 6) {
                Button {
                    if setCount > 1 {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            setCount -= 1
                            onSetCountChange(setCount)
                        }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(setCount <= 1 ? Color.secondary : Color.white)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(setCount <= 1)
                
                Text("\(setCount)")
                    .font(.body.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.white)
                    .frame(width: 28)
                    .contentTransition(.numericText())
                
                Button {
                    if setCount < 10 {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            setCount += 1
                            onSetCountChange(setCount)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(setCount >= 10 ? Color.secondary : Color.white)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(setCount >= 10)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05), in: Capsule())
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .frame(width: 30, height: 30)
                    .background(Color.red.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
        .onAppear {
            setCount = max(exercise.sets.count, 1)
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                AnimatedMeshGradientView(theme: .flow)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        // Title bar
                        HStack {
                            Button("Cancel") {
                                dismiss()
                            }
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("Add Exercises")
                                .font(.headline.weight(.semibold))
                            
                            Spacer()
                            
                            Button("Add (\(selectedNames.count))") {
                                let exercises = selectedNames.map { name in
                                    let type = selectedType ?? WorkoutExercise.exerciseType(for: name)
                                    let exercise = WorkoutExercise(name: name, type: type)
                                    let setCount = (type == .cardio || type == .flexibility) ? 1 : 3
                                    for _ in 0..<setCount {
                                        _ = exercise.addSet()
                                    }
                                    return exercise
                                }
                                onSelect(exercises)
                                dismiss()
                            }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(selectedNames.isEmpty ? Color.secondary : Color.green)
                            .disabled(selectedNames.isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // Type filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                GlassTypeChip(label: "All", isSelected: selectedType == nil) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedType = nil
                                    }
                                }
                                
                                ForEach(ExerciseType.allCases, id: \.self) { type in
                                    GlassTypeChip(
                                        label: type.title,
                                        icon: type.icon,
                                        color: colorForType(type),
                                        isSelected: selectedType == type
                                    ) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            selectedType = type
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                    
                    // Exercise list
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredExercises, id: \.self) { name in
                                ExercisePickerRow(
                                    name: name,
                                    type: WorkoutExercise.exerciseType(for: name),
                                    isSelected: selectedNames.contains(name),
                                    colorForType: colorForType
                                ) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        if selectedNames.contains(name) {
                                            selectedNames.remove(name)
                                        } else {
                                            selectedNames.insert(name)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                    
                    // Search bar at bottom
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Search exercises", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Glass Type Chip

private struct GlassTypeChip: View {
    let label: String
    var icon: String? = nil
    var color: Color = .white
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : color)
                }
                
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.green.gradient)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Picker Row

private struct ExercisePickerRow: View {
    let name: String
    let type: ExerciseType
    let isSelected: Bool
    let colorForType: (ExerciseType) -> Color
    let action: () -> Void
    
    private var color: Color { colorForType(type) }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon with colored ring
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.4), lineWidth: 2)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                // Exercise name
                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.white)
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.green.opacity(0.1) : Color.white.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.green.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
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
