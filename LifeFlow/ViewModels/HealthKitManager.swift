//
//  HealthKitManager.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation
import HealthKit
import Observation

// TimeScope is defined in AnalyticsCharts.swift and accessible within the module

/// Manages HealthKit integration for syncing workout data.
/// Uses iOS 17+ async/await patterns for querying workout samples.
/// iOS 26+: Supports live workout sessions with HKWorkoutSession and HKWorkoutBuilder.
@Observable
final class HealthKitManager: NSObject {
    // MARK: - Published State
    
    /// Current authorization status for workouts
    private(set) var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    /// Whether HealthKit is available on this device
    private(set) var isAvailable: Bool = false
    
    /// Whether a sync operation is in progress
    private(set) var isSyncing: Bool = false
    
    /// Last error encountered during operations
    private(set) var lastError: Error?
    
    /// Whether a live workout session is currently active
    private(set) var isLiveWorkoutActive: Bool = false
    
    /// Current heart rate during live workout (if available)
    private(set) var currentHeartRate: Double?
    
    /// Active calories burned during current workout
    private(set) var activeCalories: Double = 0
    
    /// Current distance in miles during specialized running workout
    private(set) var currentSessionDistance: Double = 0
    
    /// Current pace in seconds per mile
    private(set) var currentPace: Double = 0
    
    // MARK: - Private Properties
    
    private let healthStore = HKHealthStore()
    
    /// The workout type we're interested in reading/writing
    private let workoutType = HKWorkoutType.workoutType()
    
    /// Types we want to read from HealthKit
    private var typesToRead: Set<HKObjectType> {
        [
            workoutType,
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
    }
    
    /// Types we want to write to HealthKit
    private var typesToWrite: Set<HKSampleType> {
        [
            workoutType,
            HKQuantityType(.activeEnergyBurned)
        ]
    }
    
    /// Active workout session (iOS 26+ on iPhone)
    private var workoutSession: HKWorkoutSession?
    
    /// Workout builder for constructing the workout
    private var workoutBuilder: HKWorkoutBuilder?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        isAvailable = HKHealthStore.isHealthDataAvailable()
        if isAvailable {
            checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    
    /// Check current authorization status for reading workouts
    private func checkAuthorizationStatus() {
        authorizationStatus = healthStore.authorizationStatus(for: workoutType)
    }
    
    /// Request authorization to read and write workout data from HealthKit
    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        
        // Update status after request
        checkAuthorizationStatus()
    }
    
    // MARK: - Live Workout Session (iOS 26+)
    
    /// Start a live workout session
    /// - Parameter activityType: The type of workout activity
    @available(iOS 26.0, *)
    func startLiveWorkout(activityType: HKWorkoutActivityType = .traditionalStrengthTraining) async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }
        
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor // Default to outdoor for GPS tracking
        
        // Create workout session
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        workoutSession = session
        
        // Set session delegate (needed for state changes)
        // session.delegate = self // Defined in extension if needed
        
        // Create live workout builder associated with the session
        let builder = session.associatedWorkoutBuilder()
        workoutBuilder = builder
        
        // Set builder data source to automatically collect data from reliable sources
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        
        // Set delegate to receive live data updates
        builder.delegate = self
        
        // Start the session
        session.startActivity(with: Date())
        
        // Begin data collection
        // Begin data collection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: Date()) { (success, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.queryFailed(NSError(domain: "HKLiveWorkoutBuilder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error starting collection"])))
                }
            }
        }
        
        // Reset local state
        await MainActor.run {
            self.isLiveWorkoutActive = true
            self.activeCalories = 0
            self.currentHeartRate = nil
            self.currentSessionDistance = 0
            self.currentPace = 0
        }
    }
    
    /// Start a running workout specifically for Marathon Coach
    @available(iOS 26.0, *)
    func startRunningWorkout() async throws {
        try await startLiveWorkout(activityType: .running)
        
        // In a real device environment, we would assign a delegate 
        // to handle live updates from HKLiveWorkoutBuilder.
        // For now, we provide the infrastructure.
    }
    
    /// Pause the live workout session
    @available(iOS 26.0, *)
    func pauseLiveWorkout() {
        workoutSession?.pause()
    }
    
    /// Resume the live workout session
    @available(iOS 26.0, *)
    func resumeLiveWorkout() {
        workoutSession?.resume()
    }
    
    /// End the live workout session and save to HealthKit
    /// - Returns: The completed HKWorkout, if successful
    @available(iOS 26.0, *)
    func endLiveWorkout() async throws -> HKWorkout? {
        guard let session = workoutSession, let builder = workoutBuilder else {
            throw HealthKitError.noActiveSession
        }
        
        // End the session
        session.end()
        
        // End collection
        try await builder.endCollection(at: Date())
        
        // Finish and save the workout
        let workout = try await builder.finishWorkout()
        
        // Cleanup
        workoutSession = nil
        workoutBuilder = nil
        isLiveWorkoutActive = false
        
        return workout
    }
    
    /// Discard the current workout without saving
    @available(iOS 26.0, *)
    func discardLiveWorkout() async {
        if let builder = workoutBuilder {
            builder.discardWorkout()
        }
        
        workoutSession?.end()
        workoutSession = nil
        workoutBuilder = nil
        isLiveWorkoutActive = false
    }
    
    /// Add a workout event (like a lap or segment marker)
    @available(iOS 26.0, *)
    func addWorkoutEvent(type: HKWorkoutEventType, date: Date = Date()) async throws {
        guard let builder = workoutBuilder else {
            throw HealthKitError.noActiveSession
        }
        
        let event = HKWorkoutEvent(type: type, dateInterval: DateInterval(start: date, duration: 0), metadata: nil)
        try await builder.addWorkoutEvents([event])
    }
    
    // MARK: - Fetching Workouts
    
    /// Fetch today's workouts from HealthKit
    /// - Returns: Array of WorkoutSession objects mapped from HKWorkout
    func fetchTodaysWorkouts() async throws -> [WorkoutSession] {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        // Clear previous error
        lastError = nil
        
        do {
            // Create date predicate for today
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let datePredicate = HKQuery.predicateForSamples(
                withStart: startOfDay,
                end: endOfDay,
                options: .strictStartDate
            )
            
            // Create query descriptor for workouts
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout(datePredicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
            )
            
            // Execute query
            let workouts = try await descriptor.result(for: healthStore)
            
            // Map HKWorkout to our WorkoutSession model
            return workouts.map { hkWorkout in
                mapToWorkoutSession(hkWorkout)
            }
            
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Fetch workouts within a date range from HealthKit
    /// - Parameters:
    ///   - startDate: The start of the date range
    ///   - endDate: The end of the date range
    /// - Returns: Array of WorkoutSession objects mapped from HKWorkout
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        lastError = nil
        
        do {
            let datePredicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )
            
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout(datePredicate)],
                sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
            )
            
            let workouts = try await descriptor.result(for: healthStore)
            
            return workouts.map { hkWorkout in
                mapToWorkoutSession(hkWorkout)
            }
            
        } catch {
            lastError = error
            throw error
        }
    }
    
    /// Fetch workouts for a given time scope
    /// - Parameter scope: The time scope (week, month, year)
    /// - Returns: Array of WorkoutSession objects
    func fetchWorkouts(for scope: TimeScope) async throws -> [WorkoutSession] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch scope {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now)!
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now)!
        }
        
        return try await fetchWorkouts(from: startDate, to: now)
    }
    
    // MARK: - Running Workouts (Marathon Coach)

    /// Fetch running workouts from a date range for marathon coach matching
    func fetchRunningWorkouts(from startDate: Date, to endDate: Date) async throws -> [WorkoutSession] {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }

        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, runningPredicate])

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(compoundPredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )

        let workouts = try await descriptor.result(for: healthStore)
        return workouts.map { mapToWorkoutSession($0) }
    }

    // MARK: - Mapping
    
    /// Convert an HKWorkout to our WorkoutSession model
    /// - Parameter hkWorkout: The HealthKit workout to convert
    /// - Returns: A WorkoutSession instance
    private func mapToWorkoutSession(_ hkWorkout: HKWorkout) -> WorkoutSession {
        // Get activity type name
        let typeName = workoutActivityTypeName(hkWorkout.workoutActivityType)
        
        // Get duration
        let duration = hkWorkout.duration
        
        // Get calories using statistics (modern API, avoiding deprecated totalEnergyBurned)
        var calories: Double = 0
        if let energyStats = hkWorkout.statistics(for: HKQuantityType(.activeEnergyBurned)) {
            if let sumQuantity = energyStats.sumQuantity() {
                calories = sumQuantity.doubleValue(for: .kilocalorie())
            }
        }
        
        return WorkoutSession(
            id: hkWorkout.uuid,
            type: typeName,
            duration: duration,
            calories: calories,
            source: "HealthKit",
            timestamp: hkWorkout.startDate
        )
    }
    
    /// Convert HKWorkoutActivityType to a human-readable string
    /// - Parameter activityType: The HealthKit activity type
    /// - Returns: User-friendly activity name
    private func workoutActivityTypeName(_ activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Weightlifting"
        case .highIntensityIntervalTraining: return "HIIT"
        case .pilates: return "Pilates"
        case .dance, .socialDance: return "Dance"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stairs"
        case .hiking: return "Hiking"
        case .crossTraining: return "Cross Training"
        case .coreTraining: return "Core"
        case .flexibility: return "Stretching"
        case .mixedCardio: return "Cardio"
        case .cooldown: return "Cooldown"
        case .jumpRope: return "Jump Rope"
        case .kickboxing: return "Kickboxing"
        case .boxing: return "Boxing"
        case .martialArts: return "Martial Arts"
        case .tennis: return "Tennis"
        case .basketball: return "Basketball"
        case .soccer: return "Soccer"
        case .golf: return "Golf"
        default: return "Workout"
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

@available(iOS 26.0, *)
extension HealthKitManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            // Dispatch to main actor to update published properties
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                guard let statistics = workoutBuilder.statistics(for: quantityType) else { return }
                
                switch quantityType {
                case HKQuantityType(.distanceWalkingRunning):
                    let meterValue = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                    self.currentSessionDistance = meterValue / 1609.34 // Convert meters to miles
                    
                case HKQuantityType(.activeEnergyBurned):
                    let kcalValue = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    self.activeCalories = kcalValue
                    
                case HKQuantityType(.heartRate):
                    // Heart rate is usually discrete, but builder gives stats. 
                    // Use most recent if available, or average.
                    if let quantity = statistics.mostRecentQuantity() {
                        self.currentHeartRate = quantity.doubleValue(for: countPerMinuteUnit)
                    }
                    
                default:
                    break
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle events like auto-pause/resume
        DispatchQueue.main.async {
            // Potential future use: sync UI state if builder auto-pauses
        }
    }
}

// Helper unit
private let countPerMinuteUnit = HKUnit.count().unitDivided(by: .minute())
// MARK: - Error Types

extension HealthKitManager {
    enum HealthKitError: LocalizedError {
        case notAvailable
        case authorizationDenied
        case queryFailed(Error)
        case noActiveSession
        
        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device."
            case .authorizationDenied:
                return "Permission to access workout data was denied."
            case .queryFailed(let error):
                return "Failed to fetch workouts: \(error.localizedDescription)"
            case .noActiveSession:
                return "No active workout session."
            }
        }
    }
}
