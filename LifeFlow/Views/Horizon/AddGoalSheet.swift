//
//  AddGoalSheet.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData

struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var targetAmountString: String = ""
    @State private var currentAmountString: String = ""
    @State private var selectedUnit: UnitType = .currency
    @State private var selectedType: GoalType = .savings
    @State private var deadline: Date = Date().addingTimeInterval(86400 * 30) // 30 days default
    @State private var showRaceOnboarding: Bool = false

    // Type-specific unit options
    private var availableUnits: [UnitType] {
        switch selectedType {
        case .savings:
            return [.currency]
        case .weightLoss:
            return [.weight]
        case .study:
            return [.time]
        case .habit:
            return [.count]
        case .raceTraining:
            return [.distance]
        case .custom:
            return UnitType.allCases
        }
    }
    
    // Placeholder text based on goal type
    private var targetPlaceholder: String {
        switch selectedType {
        case .savings: return "Target Amount ($)"
        case .weightLoss: return "Target Weight (lbs)"
        case .study: return "Total Hours"
        case .habit: return "Times to Complete"
        case .raceTraining: return "Race Distance (mi)"
        case .custom: return "Target Amount"
        }
    }

    // Title placeholder based on goal type
    private var titlePlaceholder: String {
        switch selectedType {
        case .savings: return "e.g. New Mac, Vacation Fund"
        case .weightLoss: return "e.g. Summer Body, Healthy Weight"
        case .study: return "e.g. Swift Mastery, MCAT Prep"
        case .habit: return "e.g. Daily Meditation, Read Books"
        case .raceTraining: return "e.g. Spring Half Marathon"
        case .custom: return "e.g. My Goal"
        }
    }
    
    var isFormValid: Bool {
        !title.isEmpty && Double(targetAmountString) != nil
    }
    
    var smartPreviewText: String {
        guard let target = Double(targetAmountString), !title.isEmpty else {
            return "Enter details to see your plan."
        }
        
        let current = Double(currentAmountString) ?? 0
        let remaining = target - current
        
        if remaining <= 0 {
            return "You've already reached this target!"
        }
        
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfDay = calendar.startOfDay(for: deadline)
        let components = calendar.dateComponents([.day], from: startOfToday, to: endOfDay)
        let days = max(1, Double(components.day ?? 1))
        
        let dailyRate = remaining / days
        
        switch selectedType {
        case .savings:
            let formattedDaily = String(format: "$%.2f", dailyRate)
            let formattedTarget = String(format: "$%.0f", target)
            return "Save \(formattedDaily)/day to reach \(formattedTarget) in \(Int(days)) days."
            
        case .weightLoss:
            let weeklyRate = dailyRate * 7
            let formattedWeekly = String(format: "%.1f", weeklyRate)
            return "Lose \(formattedWeekly) lbs/week to reach \(String(format: "%.0f", target)) lbs in \(Int(days)) days."
            
        case .study:
            let formattedDaily = String(format: "%.1f", dailyRate)
            return "Study \(formattedDaily) hours/day to complete \(String(format: "%.0f", target)) hours in \(Int(days)) days."
            
        case .habit:
            return "Complete \(Int(target)) times over \(Int(days)) days (\(String(format: "%.1f", dailyRate))/day avg)."
            
        case .raceTraining:
            return "Use the Race Training setup for a personalized plan."

        case .custom:
            let formattedDaily = String(format: "%.2f", dailyRate)
            return "Add \(formattedDaily) \(selectedUnit.symbol)/day to reach \(String(format: "%.0f", target)) in \(Int(days)) days."
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Type Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("I want to...")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(GoalType.allCases, id: \.self) { type in
                                        Button {
                                            withAnimation(.spring(response: 0.3)) {
                                                selectedType = type
                                                // Auto-select appropriate unit
                                                selectedUnit = defaultUnit(for: type)
                                            }
                                        } label: {
                                            VStack(spacing: 8) {
                                                Image(systemName: type.icon)
                                                    .font(.title2)
                                                Text(type.title)
                                                    .font(.caption.weight(.semibold))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                            }
                                            .frame(width: 90, height: 90)
                                            .background(
                                                selectedType == type 
                                                    ? colorForType(type).opacity(0.15) 
                                                    : Color(uiColor: .secondarySystemGroupedBackground),
                                                in: RoundedRectangle(cornerRadius: 16)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(selectedType == type ? colorForType(type) : .clear, lineWidth: 2)
                                            )
                                            .foregroundStyle(selectedType == type ? colorForType(type) : .primary)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Race Training redirect
                        if selectedType == .raceTraining {
                            VStack(spacing: 16) {
                                Image(systemName: "figure.run.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.green)

                                Text("Set up your race training plan with our guided onboarding.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)

                                Button {
                                    showRaceOnboarding = true
                                } label: {
                                    Label("Set Up Race Training", systemImage: "arrow.right.circle.fill")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(.green, in: RoundedRectangle(cornerRadius: 16))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        }

                        // 2. Type-Specific Details (non-race types)
                        if selectedType != .raceTraining {
                        VStack(spacing: 0) {
                            // Title
                            HStack {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.secondary)
                                TextField(titlePlaceholder, text: $title)
                                    .font(.body)
                            }
                            .padding()
                            
                            Divider()
                                .padding(.leading)
                            
                            // Target - Type Specific
                            typeSpecificTargetInput
                            
                            Divider()
                                .padding(.leading)
                            
                            // Starting value (for weight loss)
                            if selectedType == .weightLoss {
                                HStack {
                                    Image(systemName: "scalemass")
                                        .foregroundStyle(.secondary)
                                    TextField("Current Weight (lbs)", text: $currentAmountString)
                                        .keyboardType(.decimalPad)
                                    Text("lbs")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                
                                Divider()
                                    .padding(.leading)
                            }
                            
                            // Deadline
                            DatePicker(selection: $deadline, displayedComponents: .date) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.secondary)
                                    Text("Deadline")
                                }
                            }
                            .padding()
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        } // end if selectedType != .raceTraining

                        // 3. Smart Preview
                        if !title.isEmpty || !targetAmountString.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Smart Preview", systemImage: "sparkles")
                                    .font(.headline)
                                    .foregroundStyle(colorForType(selectedType))
                                
                                Text(smartPreviewText)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(colorForType(selectedType).opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if selectedType != .raceTraining {
                        Button("Create") {
                            createGoal()
                        }
                        .disabled(!isFormValid)
                        .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $showRaceOnboarding) {
                RaceOnboardingSheet()
            }
        }
    }

    // MARK: - Type-Specific Input
    
    @ViewBuilder
    private var typeSpecificTargetInput: some View {
        switch selectedType {
        case .savings:
            // Currency input with dollar sign
            HStack {
                Image(systemName: "dollarsign.circle")
                    .foregroundStyle(.yellow)
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $targetAmountString)
                    .keyboardType(.decimalPad)
                Text("USD")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
            .padding()
            
        case .weightLoss:
            // Weight input with lbs
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.green)
                TextField("Goal Weight", text: $targetAmountString)
                    .keyboardType(.decimalPad)
                Text("lbs")
                    .foregroundStyle(.secondary)
            }
            .padding()
            
        case .study:
            // Time input with hours
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.purple)
                TextField("Total Hours", text: $targetAmountString)
                    .keyboardType(.decimalPad)
                Text("hours")
                    .foregroundStyle(.secondary)
            }
            .padding()
            
        case .habit:
            // Count input
            HStack {
                Image(systemName: "flame")
                    .foregroundStyle(.orange)
                TextField("Times", text: $targetAmountString)
                    .keyboardType(.numberPad)
                Text("times")
                    .foregroundStyle(.secondary)
            }
            .padding()
            
        case .raceTraining:
            // Handled by RaceOnboardingSheet
            EmptyView()

        case .custom:
            // Generic with unit picker
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.blue)
                TextField("Target Amount", text: $targetAmountString)
                    .keyboardType(.decimalPad)

                Picker("Unit", selection: $selectedUnit) {
                    ForEach(UnitType.allCases, id: \.self) { unit in
                        Text(unit.rawValue.capitalized).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding()
        }
    }
    
    // MARK: - Helpers
    
    private func defaultUnit(for type: GoalType) -> UnitType {
        switch type {
        case .savings: return .currency
        case .weightLoss: return .weight
        case .study: return .time
        case .habit: return .count
        case .raceTraining: return .distance
        case .custom: return .count
        }
    }

    private func colorForType(_ type: GoalType) -> Color {
        switch type {
        case .savings: return .yellow
        case .weightLoss: return .green
        case .habit: return .orange
        case .study: return .purple
        case .raceTraining: return .green
        case .custom: return .blue
        }
    }
    
    private func createGoal() {
        guard let target = Double(targetAmountString) else { return }
        let current = Double(currentAmountString) ?? 0
        
        // For weight loss, current is starting weight, target is goal weight
        let startValue: Double? = selectedType == .weightLoss ? current : nil
        
        let newGoal = Goal(
            title: title,
            targetAmount: target,
            currentAmount: selectedType == .weightLoss ? current : 0,
            startDate: Date(),
            deadline: deadline,
            unit: selectedUnit,
            type: selectedType,
            startValue: startValue
        )
        
        modelContext.insert(newGoal)
        try? modelContext.save()
        SoundManager.shared.play(.successChime, volume: 0.58)
        SoundManager.shared.haptic(.success)
        dismiss()
    }
}

#Preview {
    AddGoalSheet()
        .preferredColorScheme(.dark)
}
