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
    @State private var selectedType: GoalType = .targetValue
    @State private var deadline: Date = Date().addingTimeInterval(86400 * 30) // 30 days default
    
    var isFormValid: Bool {
        !title.isEmpty && Double(targetAmountString) != nil
    }
    
    var smartPreviewText: String {
        guard let target = Double(targetAmountString), !title.isEmpty else {
            return "Enter details to see your plan."
        }
        
        // Ensure inputs are valid
        let current = Double(currentAmountString) ?? 0
        let remaining = target - current
        
        if remaining <= 0 {
            return "You've already reached this target!"
        }
        
        // Calculate days
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfDay = calendar.startOfDay(for: deadline)
        let components = calendar.dateComponents([.day], from: startOfToday, to: endOfDay)
        let days = max(1, Double(components.day ?? 1))
        
        let dailyRate = remaining / days
        
        let unitSymbol = selectedUnit.symbol
        let formattedDaily = String(format: "%.2f", dailyRate)
        let formattedTarget = String(format: "%.0f", target)
        
        let actionVerb: String
        switch selectedType {
        case .targetValue: actionVerb = "save/add"
        case .frequency: actionVerb = "do"
        case .dailyHabit: actionVerb = "complete"
        }
        
        // "This means you need to save $5.50 per day."
        // Or "To reach 'Car' ($2000) by Dec 31..." - keeping concise as requested
        
        if selectedUnit == .currency {
            return "To reached \(formattedTarget) \(unitSymbol) in \(Int(days)) days, you need to set aside \(unitSymbol)\(formattedDaily) daily."
        } else {
            return "To reach \(formattedTarget) \(unitSymbol) in \(Int(days)) days, you need to \(actionVerb) \(formattedDaily) \(unitSymbol) daily."
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Subtle background
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
                                            selectedType = type
                                        } label: {
                                            VStack(spacing: 8) {
                                                Image(systemName: iconForType(type))
                                                    .font(.title2)
                                                Text(type.title)
                                                    .font(.caption.weight(.semibold))
                                            }
                                            .frame(width: 100, height: 100)
                                            .background(
                                                selectedType == type ? Color.accentColor.opacity(0.1) : Color(uiColor: .secondarySystemGroupedBackground),
                                                in: RoundedRectangle(cornerRadius: 16)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(selectedType == type ? Color.accentColor : .clear, lineWidth: 2)
                                            )
                                            .foregroundStyle(selectedType == type ? Color.accentColor : .primary)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // 2. Details
                        VStack(spacing: 0) {
                            // Title
                            HStack {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.secondary)
                                TextField("Goal Title (e.g. New Mac)", text: $title)
                                    .font(.body)
                            }
                            .padding()
                            
                            Divider()
                                .padding(.leading)
                            
                            // Target & Unit
                            HStack {
                                Image(systemName: "target")
                                    .foregroundStyle(.secondary)
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
                            
                            Divider()
                                .padding(.leading)
                            
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
                        
                        // 3. Smart Preview
                        if !title.isEmpty || !targetAmountString.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Smart Preview", systemImage: "sparkles")
                                    .font(.headline)
                                    .foregroundStyle(.purple)
                                
                                Text(smartPreviewText)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.purple.opacity(0.1))
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
                    Button("Create") {
                        createGoal()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func iconForType(_ type: GoalType) -> String {
        switch type {
        case .targetValue: return "flag.checkered"
        case .frequency: return "repeat"
        case .dailyHabit: return "checkmark.circle"
        }
    }
    
    private func createGoal() {
        guard let target = Double(targetAmountString) else { return }
        let current = Double(currentAmountString) ?? 0
        
        let newGoal = Goal(
            title: title,
            targetAmount: target,
            currentAmount: current,
            startDate: Date(),
            deadline: deadline,
            unit: selectedUnit,
            type: selectedType
        )
        
        modelContext.insert(newGoal)
        dismiss() // NavigationStack handles save automatically or we can context.save()
        try? modelContext.save()
    }
}

#Preview {
    AddGoalSheet()
        .preferredColorScheme(.dark)
}
