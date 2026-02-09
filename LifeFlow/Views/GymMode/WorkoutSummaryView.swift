//
//  WorkoutSummaryView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import HealthKit
import MapKit
import Charts
import UIKit

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
    @State private var routeSegments: [RunRouteSegment] = []
    @State private var mileSplits: [RunSplit] = []
    @State private var weatherStamp: String?
    @State private var targetPaceMinutesPerMile: Double?
    @State private var mapRegion: MKCoordinateRegion?
    @State private var isLoadingAnalysis: Bool = false
    @State private var analysisMessage: String?
    @State private var selectedFlowPrintFormat: FlowPrintFormat = .story
    @State private var isRenderingFlowPrint: Bool = false
    @State private var flowPrintImage: UIImage?
    @State private var flowPrintFileURL: URL?
    @State private var flowPrintCaption: String = ""
    @State private var flowPrintError: String?
    @State private var showFlowPrintShareSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Celebration header
                    celebrationHeader
                    
                    // Stats grid
                    statsGrid
                    
                    raceDayAnalysisSection
                    
                    flowPrintSection
                    
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
        .task(id: session.id) {
            await loadRaceAnalysis()
        }
        .sheet(isPresented: $showFlowPrintShareSheet) {
            if let fileURL = flowPrintFileURL {
                ActivityShareSheet(items: [flowPrintCaption, fileURL])
            }
        }
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
    
    // MARK: - Race Analysis
    
    @ViewBuilder
    private var raceDayAnalysisSection: some View {
        if isLoadingAnalysis || weatherStamp != nil || !mileSplits.isEmpty || !routeSegments.isEmpty || analysisMessage != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("RACE DAY ANALYSIS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    Spacer()
                    if isLoadingAnalysis {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                
                if let weatherStamp {
                    Label(weatherStamp, systemImage: "cloud.sun.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let targetPaceMinutesPerMile {
                    Label("Target Pace \(formatPace(targetPaceMinutesPerMile))/mi", systemImage: "flag.checkered")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.cyan)
                }
                
                if let mapRegion, !routeSegments.isEmpty {
                    Map(initialPosition: .region(mapRegion)) {
                        ForEach(routeSegments) { segment in
                            MapPolyline(coordinates: segment.coordinates)
                                .stroke(segment.isAhead ? .green : .red, lineWidth: 4)
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 12) {
                            mapLegendDot(color: .green, label: "Ahead")
                            mapLegendDot(color: .red, label: "Behind")
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
                    }
                } else if let analysisMessage {
                    Text(analysisMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
                
                if !mileSplits.isEmpty {
                    Chart {
                        if let targetPaceMinutesPerMile {
                            RuleMark(y: .value("Target Pace", targetPaceMinutesPerMile))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .foregroundStyle(.orange)
                        }
                        
                        ForEach(mileSplits) { split in
                            BarMark(
                                x: .value("Mile", "M\(split.mile)"),
                                y: .value("Pace", split.paceMinutesPerMile)
                            )
                            .foregroundStyle(splitColor(for: split))
                        }
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine().foregroundStyle(.white.opacity(0.08))
                            AxisTick()
                            if let pace = value.as(Double.self) {
                                AxisValueLabel("\(formatPace(pace))")
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine().foregroundStyle(.white.opacity(0.08))
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var flowPrintSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FLOW PRINT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                Spacer()
                
                Picker("Format", selection: $selectedFlowPrintFormat) {
                    ForEach(FlowPrintFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            
            if let flowPrintImage {
                Image(uiImage: flowPrintImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            
            if let flowPrintError, !flowPrintError.isEmpty {
                Text(flowPrintError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            
            HStack(spacing: 10) {
                Button {
                    Task {
                        await generateFlowPrint()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRenderingFlowPrint {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                        }
                        Text(flowPrintImage == nil ? "Generate Poster" : "Regenerate")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyan.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isRenderingFlowPrint)
                
                Button {
                    showFlowPrintShareSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Share Win")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(flowPrintFileURL == nil)
            }
            
            Text("Designed for social + text. Each card now includes your full wins, not just route data.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
    
    private var resolvedCaloriesForShare: Int {
        max(estimatedCalories, Int(session.calories.rounded()))
    }
    
    private var completedExercisesForShare: Int {
        let completed = session.sortedExercises.filter { exercise in
            exercise.sortedSets.contains(where: \.isCompleted)
        }.count
        return completed > 0 ? completed : session.sortedExercises.count
    }
    
    private var totalRepsForShare: Int {
        session.sortedExercises
            .flatMap(\.sortedSets)
            .filter(\.isCompleted)
            .compactMap(\.reps)
            .reduce(0, +)
    }
    
    private var totalVolumeForShare: Int {
        let volume = session.sortedExercises
            .flatMap(\.sortedSets)
            .filter(\.isCompleted)
            .reduce(0.0) { partial, set in
                guard let weight = set.weight, let reps = set.reps else { return partial }
                return partial + (weight * Double(reps))
            }
        return Int(volume.rounded())
    }
    
    private var flowPrintRunLine: String {
        if let miles = session.runAnalysisMetadata?.completedDistanceMiles ?? (session.totalDistanceMiles > 0 ? session.totalDistanceMiles : nil) {
            if abs(miles - 3.10686) < 0.2 { return "5K Run" }
            if abs(miles - 6.21371) < 0.25 { return "10K Run" }
            if abs(miles - 13.1094) < 0.35 { return "Half Marathon" }
            if abs(miles - 26.2188) < 0.45 { return "Marathon" }
            return String(format: "%.1f mi Run", miles)
        }
        return session.type == "Running" ? "Run Session" : session.title
    }
    
    private var flowPrintDurationLine: String {
        let totalSeconds = Int(session.duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var flowPrintPaceLine: String? {
        guard let targetPaceMinutesPerMile else { return nil }
        return "Target Pace \(formatPace(targetPaceMinutesPerMile))/mi"
    }
    
    private var flowPrintHighlights: [FlowPrintHighlight] {
        var highlights: [FlowPrintHighlight] = [
            FlowPrintHighlight(icon: "clock.fill", label: "Duration", value: flowPrintDurationLine, tone: .cyan)
        ]
        
        let distance = session.totalDistanceMiles
        if distance > 0 {
            highlights.append(
                FlowPrintHighlight(
                    icon: "figure.run",
                    label: "Distance",
                    value: String(format: "%.1f mi", distance),
                    tone: .green
                )
            )
        }
        
        if completedExercisesForShare > 0 {
            highlights.append(
                FlowPrintHighlight(
                    icon: "dumbbell.fill",
                    label: "Exercises",
                    value: "\(completedExercisesForShare)",
                    tone: .orange
                )
            )
        }
        
        if totalCompletedSets > 0 {
            highlights.append(
                FlowPrintHighlight(
                    icon: "repeat",
                    label: "Sets",
                    value: "\(totalCompletedSets)",
                    tone: .purple
                )
            )
        }
        
        if resolvedCaloriesForShare > 0 {
            highlights.append(
                FlowPrintHighlight(
                    icon: "flame.fill",
                    label: "Calories",
                    value: "\(resolvedCaloriesForShare)",
                    tone: .pink
                )
            )
        }
        
        if totalVolumeForShare > 0 {
            highlights.append(
                FlowPrintHighlight(
                    icon: "scalemass.fill",
                    label: "Volume",
                    value: "\(totalVolumeForShare) lb",
                    tone: .blue
                )
            )
        }
        
        if let hydration = session.resolvedLiquidLossEstimate {
            highlights.append(
                FlowPrintHighlight(
                    icon: "drop.fill",
                    label: "Hydration",
                    value: "\(Int(hydration.rounded())) oz",
                    tone: .cyan
                )
            )
        }
        
        return highlights
    }
    
    private var flowPrintWinLine: String? {
        var wins: [String] = []
        
        if completedExercisesForShare > 0 {
            wins.append("\(completedExercisesForShare) exercises")
        }
        
        if totalCompletedSets > 0 {
            wins.append("\(totalCompletedSets) sets")
        }
        
        if totalRepsForShare > 0 {
            wins.append("\(totalRepsForShare) reps")
        }
        
        if let delta = session.resolvedGhostRunnerDelta {
            let prefix = delta >= 0 ? "ahead" : "behind"
            wins.append("\(Int(abs(delta).rounded()))s \(prefix)")
        }
        
        if wins.isEmpty {
            return nil
        }
        
        return wins.prefix(3).joined(separator: " • ")
    }
    
    private func mapLegendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
        }
    }
    
    private func splitColor(for split: RunSplit) -> Color {
        guard let targetPaceMinutesPerMile else { return .blue }
        return split.paceMinutesPerMile <= targetPaceMinutesPerMile ? .green : .red
    }
    
    private func formatPace(_ minutesPerMile: Double) -> String {
        guard minutesPerMile.isFinite, minutesPerMile > 0 else { return "--:--" }
        let totalSeconds = Int((minutesPerMile * 60).rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
    
    private func loadRaceAnalysis() async {
        guard session.type == "Running" else { return }
        
        isLoadingAnalysis = true
        defer { isLoadingAnalysis = false }
        
        weatherStamp = session.weatherStampText
        targetPaceMinutesPerMile = session.runAnalysisMetadata?.targetPaceMinutesPerMile
        analysisMessage = nil
        
        if let workoutID = session.runAnalysisMetadata?.healthKitWorkoutID {
            do {
                try? await healthKitManager.requestAuthorization()
                let routeLocations = try await healthKitManager.fetchWorkoutRouteLocations(for: workoutID)
                applyRouteAnalysis(from: routeLocations, targetPace: targetPaceMinutesPerMile)
                if routeLocations.isEmpty {
                    analysisMessage = "Route unavailable for this run. Splits are estimated from treadmill intervals."
                }
            } catch {
                analysisMessage = "Route data unavailable. Splits are estimated from recorded intervals."
            }
        } else {
            analysisMessage = "No HealthKit route attached to this workout."
        }
        
        if mileSplits.isEmpty {
            mileSplits = fallbackSplitsFromIntervals()
        }
        
        if mileSplits.isEmpty,
           let distance = session.runAnalysisMetadata?.completedDistanceMiles ?? (session.totalDistanceMiles > 0 ? session.totalDistanceMiles : nil),
           distance > 0 {
            let pace = (session.duration / 60) / distance
            if pace.isFinite, pace > 0 {
                mileSplits = [RunSplit(mile: 1, paceMinutesPerMile: pace)]
            }
        }
    }
    
    private func applyRouteAnalysis(from locations: [CLLocation], targetPace: Double?) {
        routeSegments.removeAll()
        mapRegion = nil
        mileSplits.removeAll()
        
        let sorted = locations.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count > 1 else { return }
        
        var analyzedSegments: [RunRouteSegment] = []
        var splitPoints: [RunSplit] = []
        var mileIndex = 1
        var distanceIntoMile = 0.0
        var timeIntoMile = 0.0
        
        var coordinates: [CLLocationCoordinate2D] = []
        coordinates.reserveCapacity(sorted.count)
        
        for index in 1..<sorted.count {
            let previous = sorted[index - 1]
            let current = sorted[index]
            coordinates.append(previous.coordinate)
            
            let segmentDistanceMiles = max(0, current.distance(from: previous) / 1609.34)
            let segmentDuration = max(0, current.timestamp.timeIntervalSince(previous.timestamp))
            guard segmentDistanceMiles > 0.0003, segmentDuration > 0 else { continue }
            
            let segmentPace = (segmentDuration / 60) / segmentDistanceMiles
            let isAhead: Bool
            if let targetPace, targetPace > 0 {
                isAhead = segmentPace <= targetPace
            } else {
                isAhead = true
            }
            
            analyzedSegments.append(
                RunRouteSegment(
                    coordinates: [previous.coordinate, current.coordinate],
                    isAhead: isAhead
                )
            )
            
            var remainingDistance = segmentDistanceMiles
            var remainingDuration = segmentDuration
            while remainingDistance > 0 {
                let neededForMile = 1.0 - distanceIntoMile
                if remainingDistance >= neededForMile, neededForMile > 0 {
                    let ratio = neededForMile / remainingDistance
                    let timeForMile = remainingDuration * ratio
                    timeIntoMile += timeForMile
                    let pace = timeIntoMile / 60
                    if pace.isFinite, pace > 0 {
                        splitPoints.append(RunSplit(mile: mileIndex, paceMinutesPerMile: pace))
                    }
                    
                    mileIndex += 1
                    remainingDistance -= neededForMile
                    remainingDuration -= timeForMile
                    distanceIntoMile = 0
                    timeIntoMile = 0
                } else {
                    distanceIntoMile += remainingDistance
                    timeIntoMile += remainingDuration
                    remainingDistance = 0
                    remainingDuration = 0
                }
            }
        }
        
        if let last = sorted.last {
            coordinates.append(last.coordinate)
        }
        
        routeSegments = analyzedSegments
        mileSplits = splitPoints
        mapRegion = region(for: coordinates)
    }
    
    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.35, 0.008),
            longitudeDelta: max((maxLon - minLon) * 1.35, 0.008)
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private func fallbackSplitsFromIntervals() -> [RunSplit] {
        let allIntervals = session.sortedExercises
            .flatMap(\.sortedSets)
            .compactMap(\.cardioIntervals)
            .compactMap { try? JSONDecoder().decode([CardioInterval].self, from: $0) }
            .flatMap { $0 }
        
        guard !allIntervals.isEmpty else { return [] }
        
        var splits: [RunSplit] = []
        var mileIndex = 1
        var distanceIntoMile = 0.0
        var timeIntoMile = 0.0
        
        for interval in allIntervals {
            guard let duration = interval.duration, duration > 0 else { continue }
            let distanceMiles = max(0, (interval.speed * duration) / 3600)
            guard distanceMiles > 0 else { continue }
            
            var remainingDistance = distanceMiles
            var remainingDuration = duration
            
            while remainingDistance > 0 {
                let neededForMile = 1.0 - distanceIntoMile
                if remainingDistance >= neededForMile, neededForMile > 0 {
                    let ratio = neededForMile / remainingDistance
                    let timeForMile = remainingDuration * ratio
                    timeIntoMile += timeForMile
                    let pace = timeIntoMile / 60
                    if pace.isFinite, pace > 0 {
                        splits.append(RunSplit(mile: mileIndex, paceMinutesPerMile: pace))
                    }
                    mileIndex += 1
                    remainingDistance -= neededForMile
                    remainingDuration -= timeForMile
                    distanceIntoMile = 0
                    timeIntoMile = 0
                } else {
                    distanceIntoMile += remainingDistance
                    timeIntoMile += remainingDuration
                    remainingDistance = 0
                    remainingDuration = 0
                }
            }
        }
        
        return splits
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
    
    @MainActor
    private func generateFlowPrint() async {
        isRenderingFlowPrint = true
        defer { isRenderingFlowPrint = false }
        flowPrintError = nil
        
        do {
            let renderInput = FlowPrintRenderInput(
                sessionTitle: session.title,
                runLine: flowPrintRunLine,
                durationLine: flowPrintDurationLine,
                templeLine: "The Temple",
                weatherLine: weatherStamp,
                paceLine: flowPrintPaceLine,
                highlights: flowPrintHighlights,
                winLine: flowPrintWinLine,
                completionDate: session.endTime ?? session.startTime,
                format: selectedFlowPrintFormat,
                routeSegments: routeSegments.map { segment in
                    FlowPrintRouteSegment(
                        coordinates: segment.coordinates,
                        isAhead: segment.isAhead
                    )
                }
            )
            
            let result = try FlowPrintRenderer.shared.renderPoster(input: renderInput)
            flowPrintImage = result.image
            flowPrintFileURL = result.fileURL
            flowPrintCaption = result.caption
            
            SoundManager.shared.play(.successChime, volume: 0.56)
        } catch {
            flowPrintError = error.localizedDescription
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

private struct RunRouteSegment: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let isAhead: Bool
}

private struct RunSplit: Identifiable {
    let id = UUID()
    let mile: Int
    let paceMinutesPerMile: Double
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
