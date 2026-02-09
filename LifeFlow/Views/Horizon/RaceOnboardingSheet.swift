//
//  RaceOnboardingSheet.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import SwiftUI
import SwiftData

/// Multi-step onboarding sheet for creating a race training plan.
/// Step 0: Race distance + date selection
/// Step 1: Baseline fitness assessment
/// Step 2: Schedule constraints (rest day selection)
struct RaceOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.marathonCoachManager) private var coachManager

    @State private var step: Int = 0
    @State private var selectedDistance: RaceDistance = .fiveK
    @State private var raceDate: Date = Date().addingTimeInterval(86400 * 60)
    @State private var weeklyMileageString: String = ""
    @State private var longestRunString: String = ""
    @State private var restDays: Set<Int> = []
    @State private var voiceCoachStartupMode: VoiceCoachStartupMode = MarathonCoachSettings.load().voiceCoachStartupMode

    private var weeklyMileage: Double {
        Double(weeklyMileageString) ?? 0
    }

    private var longestRun: Double {
        Double(longestRunString) ?? 0
    }

    private var weeksUntilRace: Int {
        TrainingPlanGenerator.weeksUntilRace(from: Date(), to: raceDate)
    }

    private var canProceedStep0: Bool {
        raceDate > Date().addingTimeInterval(86400 * 14)
    }

    private var canProceedStep1: Bool {
        weeklyMileage > 0 || longestRun > 0
    }

    private var canCreate: Bool {
        canProceedStep0 && canProceedStep1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                TabView(selection: $step) {
                    RaceSelectionStepView(
                        selectedDistance: $selectedDistance,
                        raceDate: $raceDate,
                        weeksUntilRace: weeksUntilRace,
                        isTooSoon: weeksUntilRace < selectedDistance.minimumWeeksNeeded
                    ).tag(0)

                    BaselineFitnessStepView(
                        weeklyMileageString: $weeklyMileageString,
                        longestRunString: $longestRunString,
                        weeklyMileage: weeklyMileage,
                        longestRun: longestRun,
                        weeksUntilRace: weeksUntilRace
                    ).tag(1)

                    ScheduleStepView(
                        restDays: $restDays,
                        voiceCoachStartupMode: $voiceCoachStartupMode,
                        selectedDistance: selectedDistance,
                        raceDate: raceDate,
                        weeklyMileage: weeklyMileage,
                        longestRun: longestRun,
                        weeksUntilRace: weeksUntilRace,
                        canCreate: canCreate
                    ).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    confirmationButton
                }
            }
        }
    }

    @ViewBuilder
    private var confirmationButton: some View {
        if step < 2 {
            Button("Next") { step += 1 }
                .disabled(step == 0 ? !canProceedStep0 : !canProceedStep1)
                .fontWeight(.bold)
        } else {
            Button("Create Plan") { createPlan() }
                .disabled(!canCreate)
                .fontWeight(.bold)
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Choose Your Race"
        case 1: return "Your Fitness Level"
        case 2: return "Your Schedule"
        default: return "Race Training"
        }
    }

    private func createPlan() {
        let inferredMileage = weeklyMileage > 0 ? weeklyMileage : longestRun * 2.5
        let inferredLongest = longestRun > 0 ? longestRun : weeklyMileage * 0.35

        coachManager.createPlan(
            raceDistance: selectedDistance,
            raceDate: raceDate,
            weeklyMileage: inferredMileage,
            longestRun: inferredLongest,
            restDays: Array(restDays),
            modelContext: modelContext
        )

        let goal = Goal(
            title: "\(selectedDistance.displayName) Training",
            targetAmount: selectedDistance.distanceInMiles,
            currentAmount: 0,
            startDate: Date(),
            deadline: raceDate,
            unit: .distance,
            type: .raceTraining,
            iconName: "figure.run"
        )
        modelContext.insert(goal)
        try? modelContext.save()
        
        var settings = MarathonCoachSettings.load()
        settings.voiceCoachStartupMode = voiceCoachStartupMode
        settings.save()

        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        dismiss()
    }
}

// MARK: - Step 0: Race Selection

private struct RaceSelectionStepView: View {
    @Binding var selectedDistance: RaceDistance
    @Binding var raceDate: Date
    let weeksUntilRace: Int
    let isTooSoon: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                StepIndicator(current: 0, total: 3)
                distancePicker
                datePicker
                infoCard
            }
            .padding(.vertical)
        }
    }

    private var distancePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Event")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(RaceDistance.allCases, id: \.self) { distance in
                    RaceDistanceButton(
                        distance: distance,
                        isSelected: selectedDistance == distance
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDistance = distance
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var datePicker: some View {
        VStack(spacing: 0) {
            DatePicker(selection: $raceDate, in: Date()..., displayedComponents: .date) {
                HStack {
                    Image(systemName: "calendar").foregroundStyle(.green)
                    Text("Race Day")
                }
            }
            .padding()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(weeksUntilRace) weeks until race day", systemImage: "clock")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)

            if isTooSoon {
                Label(
                    "Typically needs \(selectedDistance.minimumWeeksNeeded)+ weeks. Consider a later date.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            } else {
                Label("Great timeline for a proper build-up.", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Race Distance Button

private struct RaceDistanceButton: View {
    let distance: RaceDistance
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: distance.icon).font(.title2)
                Text(distance.displayName).font(.subheadline.weight(.semibold))
                Text(String(format: "%.1f mi", distance.distanceInMiles))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ? Color.green.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? .green : .clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? .green : .primary)
        }
    }
}

// MARK: - Step 1: Baseline Fitness

private struct BaselineFitnessStepView: View {
    @Binding var weeklyMileageString: String
    @Binding var longestRunString: String
    let weeklyMileage: Double
    let longestRun: Double
    let weeksUntilRace: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                StepIndicator(current: 1, total: 3)
                headerSection
                weeklyMileageInput
                longestRunInput
                previewSection
            }
            .padding(.vertical)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Help us calibrate your plan")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Text("Answer at least one question so we can set a safe starting point.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private var weeklyMileageInput: some View {
        MileageInputCard(
            icon: "calendar.badge.clock",
            label: "Typical weekly mileage",
            text: $weeklyMileageString,
            unit: "miles/week"
        )
    }

    private var longestRunInput: some View {
        MileageInputCard(
            icon: "road.lanes",
            label: "Longest run in the last month",
            text: $longestRunString,
            unit: "miles"
        )
    }

    @ViewBuilder
    private var previewSection: some View {
        if weeklyMileage > 0 || longestRun > 0 {
            let inferredWeekly = weeklyMileage > 0 ? weeklyMileage : longestRun * 2.5
            let peakWeekly = inferredWeekly * pow(1.10, Double(max(1, weeksUntilRace / 3)))
            let startText = String(format: "%.0f", inferredWeekly)
            let peakText = String(format: "%.0f", peakWeekly)

            VStack(alignment: .leading, spacing: 8) {
                Label("Plan Preview", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("Starting at \(startText) miles/week, building to \(peakText) miles/week at peak.")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

// MARK: - Mileage Input Card

private struct MileageInputCard: View {
    let icon: String
    let label: String
    @Binding var text: String
    let unit: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon).foregroundStyle(.green)
                Text(label).font(.subheadline)
                Spacer()
            }
            .padding()

            Divider().padding(.leading)

            HStack {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .frame(maxWidth: 100)
                Text(unit).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Step 2: Schedule

private struct ScheduleStepView: View {
    @Binding var restDays: Set<Int>
    @Binding var voiceCoachStartupMode: VoiceCoachStartupMode
    let selectedDistance: RaceDistance
    let raceDate: Date
    let weeklyMileage: Double
    let longestRun: Double
    let weeksUntilRace: Int
    let canCreate: Bool

    private var runDays: Int { 7 - restDays.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                StepIndicator(current: 2, total: 3)
                headerSection
                weekdaySelector
                summaryCard
                voiceCoachCard
                if canCreate { readySummary }
            }
            .padding(.vertical)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which days can you NOT run?")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Text("Tap to mark your rest days. We'll never schedule runs on these days.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private var weekdaySelector: some View {
        HStack(spacing: 8) {
            ForEach(weekdayData, id: \.number) { day in
                WeekdayToggleButton(
                    abbreviation: day.abbreviation,
                    isRest: restDays.contains(day.number)
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        if restDays.contains(day.number) {
                            restDays.remove(day.number)
                        } else {
                            restDays.insert(day.number)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(runDays) training days per week", systemImage: "figure.run")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)

            if restDays.isEmpty {
                Label("Consider at least 1-2 rest days for recovery", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            } else if restDays.count >= 5 {
                Label("Very few training days. Consider adding more.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            } else {
                Label("Good balance of training and recovery", systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    private var voiceCoachCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Voice Coach starts", systemImage: "speaker.wave.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
            
            Picker("Voice Coach starts", selection: $voiceCoachStartupMode) {
                ForEach(VoiceCoachStartupMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            Text("You can always mute or unmute during the run.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var readySummary: some View {
        let inferred = weeklyMileage > 0 ? weeklyMileage : longestRun * 2.5
        let startMileage = String(format: "%.0f mi/week start", inferred)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Ready to Go").font(.headline)
            HStack {
                Label(selectedDistance.displayName, systemImage: selectedDistance.icon)
                Spacer()
                Text(raceDate.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            HStack {
                Label("\(weeksUntilRace) weeks", systemImage: "calendar")
                Spacer()
                Text(startMileage).foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .transition(.opacity)
    }

    private var weekdayData: [(number: Int, abbreviation: String)] {
        [(1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")]
    }
}

// MARK: - Weekday Toggle Button

private struct WeekdayToggleButton: View {
    let abbreviation: String
    let isRest: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(abbreviation).font(.caption.weight(.bold))
                Image(systemName: isRest ? "bed.double.fill" : "figure.run").font(.title3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isRest ? Color.gray.opacity(0.2) : Color.green.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isRest ? Color.gray.opacity(0.5) : Color.green.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(isRest ? Color.secondary : Color.green)
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.green : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    RaceOnboardingSheet()
        .preferredColorScheme(.dark)
}
