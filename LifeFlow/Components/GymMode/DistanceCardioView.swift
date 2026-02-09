//
//  DistanceCardioView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

/// Distance-based cardio workout that counts up toward a target distance.
/// Designed for Marathon Coach integration to track running sessions.
struct DistanceCardioView: View {
    let exerciseName: String
    let targetDistance: Double  // Target in miles
    let onComplete: (Double, Double, Double, [CardioInterval]?, Bool) -> Void  // actualDistance, speed, incline, history, endedEarly
    let onCancel: () -> Void
    
    @Environment(GymModeManager.self) private var gymModeManager
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var weatherService = RunWeatherService()
    @StateObject private var liveLocationTracker = LiveRunLocationTracker()
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var hasCenteredMap = false
    
    @State private var phase: DistancePhase = .setup
    @State private var speed: Double = 5.0
    @State private var incline: Double = 0.0
    @State private var expandedSetting: CardioSetting? = nil
    @State private var hasCustomSetupSpeed: Bool = false
    
    enum CardioSetting {
        case speed
        case incline
    }
    
    @State private var currentDistance: Double = 0  // Distance covered in miles
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showCelebration: Bool = false
    @State private var showEndEarlyAlert: Bool = false
    
    // History tracking
    @State private var intervals: [CardioInterval] = []
    @State private var currentIntervalStart: Date = Date()
    
    enum DistancePhase {
        case setup
        case active
        case complete
    }
    
    var body: some View {
        ZStack {
            switch phase {
            case .setup:
                setupView
            case .active:
                activeView
            case .complete:
                celebrationView
            }
        }
        .preferredColorScheme(.dark)
        .alert("End Run Early?", isPresented: $showEndEarlyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Run", role: .destructive) {
                endWorkout(early: true)
            }
        } message: {
            Text("Are you sure you want to end your run early? Your \(String(format: "%.2f", displayDistance)) mi will be saved.")
        }
        .onAppear {
            weatherService.fetchIfNeeded()
        }
        .onDisappear {
            liveLocationTracker.stopTracking()
        }
        .onChange(of: gymModeManager.isIndoorRun) { _, isIndoor in
            if isIndoor {
                liveLocationTracker.stopTracking()
            } else if phase == .active {
                liveLocationTracker.startTracking(indoor: false)
            }
        }
        .onReceive(liveLocationTracker.$latestCoordinate.compactMap { $0 }) { coordinate in
            guard !gymModeManager.isIndoorRun else { return }
            
            if !hasCenteredMap {
                hasCenteredMap = true
                mapPosition = .region(Self.region(around: coordinate))
            } else {
                mapPosition = .camera(
                    MapCamera(
                        centerCoordinate: coordinate,
                        distance: 900,
                        heading: 0,
                        pitch: 0
                    )
                )
            }
        }
    }
    
    // MARK: - Setup View
    
    private var setupView: some View {
        VStack(spacing: 20) {
            if gymModeManager.isIndoorRun {
                // Speed and incline are user-controlled only for treadmill mode.
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        CardioSettingBox(
                            label: "Speed",
                            value: speed,
                            unit: "mph",
                            color: .green,
                            isExpanded: expandedSetting == .speed,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedSetting = expandedSetting == .speed ? nil : .speed
                                }
                            }
                        )
                        
                        CardioSettingBox(
                            label: "Incline",
                            value: incline,
                            unit: "%",
                            color: .orange,
                            isExpanded: expandedSetting == .incline,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedSetting = expandedSetting == .incline ? nil : .incline
                                }
                            }
                        )
                    }
                    
                    if let setting = expandedSetting {
                        CardioIncrementInput(
                            value: setting == .speed ? $speed : $incline,
                            unit: setting == .speed ? "mph" : "%",
                            color: setting == .speed ? .green : .orange,
                            increments: setting == .speed ? [0.1, 0.5, 1.0, 2.5] : [0.1, 0.5, 2.5, 5.0],
                            onValueChanged: {
                                if setting == .speed {
                                    hasCustomSetupSpeed = true
                                }
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.top, 4)
            } else {
                sensorMeasuredSetupPanel
                    .padding(.top, 4)
            }
            
            runEnvironmentToggle
            
            HStack(spacing: 8) {
                Image(systemName: gymModeManager.isIndoorRun ? "house.fill" : "cloud.sun.fill")
                    .foregroundStyle(gymModeManager.isIndoorRun ? .orange : .cyan)
                Text(
                    gymModeManager.isIndoorRun
                    ? "Indoor mode on. You can tune speed and incline manually."
                    : "Outdoor mode uses Apple Watch/iPhone sensors for pace and grade. \(weatherService.summaryText)"
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding()
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .padding(.top, 4)

            SlideToStartControl(
                title: "Slide to Start Guided Run",
                tint: .green,
                completionThreshold: 0.85
            ) {
                startWorkout()
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Active View
    
    private var activeView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: gymModeManager.isIndoorRun ? "house.fill" : "location.fill")
                    .foregroundStyle(gymModeManager.isIndoorRun ? .orange : .cyan)
                Text(gymModeManager.isIndoorRun ? "Indoor run" : "Outdoor run")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            
            // Progress ring with distance (Standard sizing)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 10)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                
                VStack(spacing: 2) {
                    Text(String(format: "%.2f", displayDistance))
                        .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    
                    Text("of \(String(format: "%.1f", targetDistance)) mi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
            
            // Elapsed and Pace
            HStack(spacing: 32) {
                VStack(spacing: 2) {
                    Text(formattedElapsedTime)
                        .font(.title3.weight(.bold).monospacedDigit())
                    Text("TIME")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 2) {
                    Text(formattedPace)
                        .font(.title3.weight(.bold).monospacedDigit())
                    Text("PACE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            
            if gymModeManager.isIndoorRun, shouldShowGhostRunner {
                VStack(spacing: 8) {
                    GhostRunnerBar(progress: progress, ghostProgress: ghostProgress)
                    
                    HStack {
                        Text(ghostDeltaLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ghostDelta >= 0 ? .green : .orange)
                        Spacer()
                        Text("Target \(formattedTargetPace)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 2)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if !gymModeManager.isIndoorRun {
                outdoorLiveMapPanel
            }
            
            Button {
                gymModeManager.toggleVoiceCoachMute()
            } label: {
                HStack(spacing: 8) {
                    Image("ai_coach_orb")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                        )

                    Image(systemName: gymModeManager.isVoiceCoachMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    Text(gymModeManager.isVoiceCoachMuted ? "Voice Muted" : "Voice On")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(gymModeManager.isVoiceCoachMuted ? .orange : .green)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            
            if gymModeManager.isIndoorRun {
                // Speed and incline are only editable for treadmill sessions.
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        CardioSettingBox(
                            label: "Speed",
                            value: speed,
                            unit: "mph",
                            color: .green,
                            isExpanded: expandedSetting == .speed,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedSetting = expandedSetting == .speed ? nil : .speed
                                }
                            }
                        )
                        
                        CardioSettingBox(
                            label: "Incline",
                            value: incline,
                            unit: "%",
                            color: .orange,
                            isExpanded: expandedSetting == .incline,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedSetting = expandedSetting == .incline ? nil : .incline
                                }
                            }
                        )
                    }
                    
                    if let setting = expandedSetting {
                        CardioIncrementInput(
                            value: setting == .speed ? $speed : $incline,
                            unit: setting == .speed ? "mph" : "%",
                            color: setting == .speed ? .green : .orange,
                            increments: setting == .speed ? [0.1, 0.5, 1.0, 2.5] : [0.1, 0.5, 2.5, 5.0],
                            onValueChanged: {
                                syncCardioStateToManager()
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                sensorMeasuredActivePanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // End early button
            Button {
                showEndEarlyAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                    Text("End Run Early")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Celebration View
    
    private var celebrationView: some View {
        ZStack {
            // Confetti background
            if showCelebration {
                CelebrationParticles()
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 24) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 80))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .purple)
                    .scaleEffect(showCelebration ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCelebration)
                
                Text("Run Complete! 🏃‍♂️")
                    .font(.largeTitle.weight(.bold))
                    .opacity(showCelebration ? 1 : 0)
                    .animation(.easeIn.delay(0.3), value: showCelebration)
                
                VStack(spacing: 8) {
                    Text("You ran")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("\(String(format: "%.2f", displayDistance)) miles")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.purple)
                    
                    Text("in \(formattedElapsedTime)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(showCelebration ? 1 : 0)
                .animation(.easeIn.delay(0.5), value: showCelebration)
            }
        }
        .onAppear {
            withAnimation {
                showCelebration = true
            }
            
            // Haptic feedback
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
            
            // Auto-complete after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                let finalIntervals = allIntervalsWithCurrent
                onComplete(displayDistance, speed, incline, finalIntervals, false)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var progress: Double {
        guard targetDistance > 0 else { return 0 }
        return min(1.0, displayDistance / targetDistance)
    }
    
    private var ghostProgress: Double {
        guard targetDistance > 0 else { return 0 }
        return min(1.0, expectedDistance / targetDistance)
    }
    
    private var expectedDistance: Double {
        guard let targetPace = resolvedTargetPaceMinutesPerMile, targetPace > 0 else { return 0 }
        return max(0, elapsedTime / (targetPace * 60))
    }
    
    private var ghostDelta: Double {
        displayDistance - expectedDistance
    }
    
    private var ghostDeltaLabel: String {
        if abs(ghostDelta) < 0.01 {
            return "On target"
        }
        return ghostDelta > 0
            ? String(format: "Ahead by %.2f mi", ghostDelta)
            : String(format: "Behind by %.2f mi", abs(ghostDelta))
    }
    
    private var resolvedTargetPaceMinutesPerMile: Double? {
        if let pace = gymModeManager.targetPaceMinutesPerMile, pace > 0 {
            return pace
        }
        guard speed > 0 else { return nil }
        return 60 / speed
    }
    
    private var shouldShowGhostRunner: Bool {
        guard let targetPace = resolvedTargetPaceMinutesPerMile, targetPace > 0 else {
            return false
        }
        
        guard let session = gymModeManager.activeTrainingSession else {
            return false
        }
        
        switch session.runType {
        case .recovery, .crossTraining, .rest:
            return false
        default:
            return true
        }
    }
    
    private var formattedTargetPace: String {
        guard let pace = resolvedTargetPaceMinutesPerMile else { return "--:-- /mi" }
        let totalSeconds = Int((pace * 60).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /mi", minutes, seconds)
    }
    
    private var remainingDistance: Double {
        max(0, targetDistance - displayDistance)
    }
    
    private var displayDistance: Double {
        // Indoor sessions prioritize local treadmill progression.
        if gymModeManager.isIndoorRun {
            if currentDistance > 0 {
                return currentDistance
            }
            if healthKitManager.currentSessionDistance > 0 {
                return healthKitManager.currentSessionDistance
            }
            return 0
        }
        
        // Outdoor sessions prioritize GPS-backed HealthKit distance.
        if healthKitManager.currentSessionDistance > 0 {
            return healthKitManager.currentSessionDistance
        }
        if liveLocationTracker.trackedDistanceMiles > 0 {
            return liveLocationTracker.trackedDistanceMiles
        }
        return currentDistance
    }

    private var sensorSpeedForOutdoor: Double {
        if let liveSpeed = liveLocationTracker.currentSpeedMPH, liveSpeed > 0.05 {
            return liveSpeed
        }
        
        guard elapsedTime > 0 else { return 0 }
        return max(0, (displayDistance / elapsedTime) * 3600)
    }
    
    private var sensorInclineForOutdoor: Double {
        if let liveGrade = liveLocationTracker.currentGradePercent, liveGrade.isFinite {
            return liveGrade
        }
        return 0
    }
    
    private var speedDisplayText: String {
        let speedValue = sensorSpeedForOutdoor
        if speedValue <= 0.05 { return "Auto" }
        return String(format: "%.1f mph", speedValue)
    }
    
    private var inclineDisplayText: String {
        let inclineValue = sensorInclineForOutdoor
        if abs(inclineValue) < 0.05 { return "0.0%" }
        return String(format: "%+.1f%%", inclineValue)
    }
    
    private var sensorMeasuredSetupPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                SensorReadoutBox(
                    label: "Speed",
                    valueText: "Auto",
                    detailText: "From GPS/Watch",
                    color: .green
                )
                SensorReadoutBox(
                    label: "Incline",
                    valueText: "Auto",
                    detailText: "From elevation",
                    color: .orange
                )
            }
            Text("Outdoor guided runs are sensor-driven. Manual speed and incline input is disabled.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var sensorMeasuredActivePanel: some View {
        HStack(spacing: 12) {
            SensorReadoutBox(
                label: "Speed",
                valueText: speedDisplayText,
                detailText: "Measured live",
                color: .green
            )
            SensorReadoutBox(
                label: "Incline",
                valueText: inclineDisplayText,
                detailText: "Measured live",
                color: .orange
            )
        }
    }
    
    @ViewBuilder
    private var outdoorLiveMapPanel: some View {
        if liveLocationTracker.canDisplayMap {
            ZStack(alignment: .topLeading) {
                Map(position: $mapPosition) {
                    UserAnnotation()
                    
                    if liveLocationTracker.routeCoordinates.count > 1 {
                        MapPolyline(coordinates: liveLocationTracker.routeCoordinates)
                            .stroke(.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                
                Label("Live Route", systemImage: "location.north.line.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(10)
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: liveLocationTracker.isDenied ? "location.slash.fill" : "location.circle.fill")
                    .foregroundStyle(.orange)
                Text(liveLocationTracker.isDenied ? "Enable location for live route mapping." : "Acquiring your location for live route map…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding()
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }
    }
    
    private var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let mins = (Int(elapsedTime) % 3600) / 60
        let secs = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
    
    private var formattedPace: String {
        guard displayDistance > 0 else { return "--:-- /mi" }
        let paceSeconds = elapsedTime / displayDistance
        let mins = Int(paceSeconds) / 60
        let secs = Int(paceSeconds) % 60
        return String(format: "%d:%02d /mi", mins, secs)
    }
    
    private var allIntervalsWithCurrent: [CardioInterval] {
        let all = intervals
        var current = CardioInterval(speed: speed, incline: incline)
        current.duration = Date().timeIntervalSince(currentIntervalStart)
        return all + [current]
    }
    
    // MARK: - Actions
    
    private func startWorkout() {
        currentDistance = 0
        elapsedTime = 0
        phase = .active
        SoundManager.shared.play(.startGun, volume: 0.62)
        gymModeManager.isCardioInProgress = true
        hasCenteredMap = false
        mapPosition = .automatic
        liveLocationTracker.resetRoute()
        liveLocationTracker.startTracking(indoor: gymModeManager.isIndoorRun)
        let setupSpeedOverride = gymModeManager.isIndoorRun && hasCustomSetupSpeed ? speed : nil
        gymModeManager.beginGuidedDistanceRun(
            setupSpeedMPH: setupSpeedOverride,
            weatherSummary: weatherService.summaryText
        )
        hasCustomSetupSpeed = false
        
        // Start live tracking if possible
        gymModeManager.startHealthKitRun(hkManager: healthKitManager)
        syncCardioStateToManager()
        
        // Init history
        currentIntervalStart = Date()
        intervals = []
        
        // Start timer - update every second
        // Distance is simulated based on speed (mph converted to miles per second)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard !gymModeManager.isPaused else { return }
            elapsedTime += 1
            
            if gymModeManager.isIndoorRun {
                // Treadmill sessions use user-set speed and simulated progression.
                let distanceThisSecond = speed / 3600.0
                currentDistance += distanceThisSecond
            } else {
                // Outdoor sessions are sensor-driven (HealthKit distance + GPS fallback).
                speed = sensorSpeedForOutdoor
                incline = sensorInclineForOutdoor
            }
            
            syncCardioStateToManager()
            
            // Check if target reached
            if displayDistance >= targetDistance {
                timer?.invalidate()
                timer = nil
                gymModeManager.isCardioInProgress = false
                liveLocationTracker.stopTracking()
                phase = .complete
            }
        }
    }
    
    private var runEnvironmentToggle: some View {
        HStack(spacing: 0) {
            environmentOption(
                title: "Outdoors",
                icon: "map.fill",
                isIndoor: false
            )
            environmentOption(
                title: "Treadmill",
                icon: "house.fill",
                isIndoor: true
            )
        }
        .padding(4)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func environmentOption(title: String, icon: String, isIndoor: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                gymModeManager.isIndoorRun = isIndoor
                if !isIndoor {
                    expandedSetting = nil
                    hasCustomSetupSpeed = false
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(gymModeManager.isIndoorRun == isIndoor ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                if gymModeManager.isIndoorRun == isIndoor {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isIndoor ? Color.orange.gradient : Color.cyan.gradient)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func recordInterval(oldSpeed: Double, oldIncline: Double) {
        var interval = CardioInterval(speed: oldSpeed, incline: oldIncline)
        let duration = Date().timeIntervalSince(currentIntervalStart)
        interval.duration = duration
        
        if duration > 1 {
            intervals.append(interval)
        }
        
        currentIntervalStart = Date()
    }
    
    private func endWorkout(early: Bool) {
        timer?.invalidate()
        timer = nil
        gymModeManager.isCardioInProgress = false
        liveLocationTracker.stopTracking()
        
        let finalIntervals = allIntervalsWithCurrent
        syncCardioStateToManager()
        onComplete(displayDistance, speed, incline, finalIntervals, early)
    }

    private func syncCardioStateToManager() {
        let cardioSpeed = gymModeManager.isIndoorRun ? speed : sensorSpeedForOutdoor
        let cardioIncline = gymModeManager.isIndoorRun ? incline : sensorInclineForOutdoor
        
        gymModeManager.updateCardioState(
            mode: 2,
            endTime: nil,
            speed: cardioSpeed,
            incline: cardioIncline,
            elapsedTime: elapsedTime,
            duration: targetDistance,
            currentDistance: displayDistance
        )
    }
    
    private static func region(around coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
}

private final class LiveRunLocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var latestCoordinate: CLLocationCoordinate2D?
    @Published private(set) var trackedDistanceMiles: Double = 0
    @Published private(set) var currentSpeedMPH: Double?
    @Published private(set) var currentGradePercent: Double?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var locationError: String?
    
    private let locationManager = CLLocationManager()
    private var lastRecordedLocation: CLLocation?
    private var isTracking = false
    
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
    
    var canDisplayMap: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func startTracking(indoor: Bool) {
        guard !indoor else {
            stopTracking()
            return
        }
        isTracking = true
        
        requestAuthorizationIfNeeded()
        
        if canDisplayMap {
            locationManager.startUpdatingLocation()
        }
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        isTracking = false
    }
    
    func resetRoute() {
        routeCoordinates.removeAll()
        latestCoordinate = nil
        lastRecordedLocation = nil
        trackedDistanceMiles = 0
        currentSpeedMPH = nil
        currentGradePercent = nil
        locationError = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if canDisplayMap, isTracking {
            manager.startUpdatingLocation()
        } else if isDenied {
            stopTracking()
            locationError = "Location access denied."
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            guard location.horizontalAccuracy >= 0 else { continue }
            
            latestCoordinate = location.coordinate
            updateSpeed(using: location)
            
            if let last = lastRecordedLocation {
                let delta = location.distance(from: last)
                if delta >= 5 {
                    routeCoordinates.append(location.coordinate)
                    trackedDistanceMiles += delta / 1609.34
                    updateGrade(from: last, to: location, horizontalDistance: delta)
                    lastRecordedLocation = location
                }
            } else {
                routeCoordinates.append(location.coordinate)
                lastRecordedLocation = location
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error.localizedDescription
    }
    
    private func requestAuthorizationIfNeeded() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .restricted, .denied:
            break
        @unknown default:
            break
        }
    }
    
    private func updateSpeed(using location: CLLocation) {
        guard location.speed >= 0 else { return }
        let speedMPH = location.speed * 2.23693629
        guard speedMPH.isFinite else { return }
        
        if let existingSpeed = currentSpeedMPH {
            currentSpeedMPH = (existingSpeed * 0.65) + (speedMPH * 0.35)
        } else {
            currentSpeedMPH = speedMPH
        }
    }
    
    private func updateGrade(from last: CLLocation, to current: CLLocation, horizontalDistance: Double) {
        guard horizontalDistance >= 3 else { return }
        guard last.verticalAccuracy >= 0, current.verticalAccuracy >= 0 else { return }
        
        let verticalRise = current.altitude - last.altitude
        let gradePercent = (verticalRise / horizontalDistance) * 100
        guard gradePercent.isFinite else { return }
        
        let clampedGrade = min(30, max(-30, gradePercent))
        if let existingGrade = currentGradePercent {
            currentGradePercent = (existingGrade * 0.7) + (clampedGrade * 0.3)
        } else {
            currentGradePercent = clampedGrade
        }
    }
}

private struct SensorReadoutBox: View {
    let label: String
    let valueText: String
    let detailText: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            Text(valueText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Text(detailText)
                .font(.caption2)
                .foregroundStyle(color.opacity(0.85))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Distance Cardio - 3 miles") {
    DistanceCardioView(
        exerciseName: "Run",
        targetDistance: 3.0,
        onComplete: { distance, speed, incline, intervals, early in
            print("Completed: \(distance) mi")
        },
        onCancel: { }
    )
}

#Preview("Distance Cardio - 5K") {
    DistanceCardioView(
        exerciseName: "5K Run",
        targetDistance: 3.1,
        onComplete: { _, _, _, _, _ in },
        onCancel: { }
    )
}
