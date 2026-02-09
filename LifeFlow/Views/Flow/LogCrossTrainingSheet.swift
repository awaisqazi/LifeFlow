//
//  LogCrossTrainingSheet.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI
import HealthKit

struct CrossTrainingLogEntry {
    let activityType: HKWorkoutActivityType
    let displayName: String
    let durationMinutes: Int
    let saveToHealth: Bool
}

struct LogCrossTrainingSheet: View {
    let session: TrainingSession
    let onSubmit: (CrossTrainingLogEntry) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedOption: CrossTrainingOption = .strength
    @State private var durationMinutes: Int = 45
    @State private var saveToHealth: Bool = true
    
    private struct CrossTrainingOption: Identifiable, Hashable {
        let id = UUID()
        let label: String
        let icon: String
        let activityType: HKWorkoutActivityType
        
        static let yoga = CrossTrainingOption(label: "Yoga", icon: "figure.yoga", activityType: .yoga)
        static let strength = CrossTrainingOption(label: "Strength", icon: "dumbbell.fill", activityType: .functionalStrengthTraining)
        static let cycling = CrossTrainingOption(label: "Cycling", icon: "figure.outdoor.cycle", activityType: .cycling)
        static let swimming = CrossTrainingOption(label: "Swimming", icon: "figure.pool.swim", activityType: .swimming)
        
        static let all: [CrossTrainingOption] = [.yoga, .strength, .cycling, .swimming]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: session.runType.icon)
                            .font(.system(size: 36))
                            .foregroundStyle(.cyan)
                        
                        Text("Log Cross Training")
                            .font(.title2.weight(.bold))
                        
                        Text("Record today’s non-running workout")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(CrossTrainingOption.all) { option in
                            Button {
                                selectedOption = option
                            } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: option.icon)
                                        .font(.title2)
                                    Text(option.label)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    selectedOption == option
                                        ? Color.cyan.opacity(0.2)
                                        : Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedOption == option ? Color.cyan : .clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Duration")
                                .font(.headline)
                            Spacer()
                            Text("\(durationMinutes) min")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.cyan)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(durationMinutes) },
                            set: { durationMinutes = Int($0.rounded()) }
                        ), in: 10...180, step: 5)
                        .tint(.cyan)
                        
                        Toggle("Save to Apple Health", isOn: $saveToHealth)
                            .font(.subheadline)
                            .tint(.green)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    Button {
                        onSubmit(
                            CrossTrainingLogEntry(
                                activityType: selectedOption.activityType,
                                displayName: selectedOption.label,
                                durationMinutes: durationMinutes,
                                saveToHealth: saveToHealth
                            )
                        )
                        dismiss()
                    } label: {
                        Text("Log Activity")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Cross Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    LogCrossTrainingSheet(
        session: TrainingSession(date: Date(), runType: .crossTraining, targetDistance: 0)
    ) { _ in }
}
