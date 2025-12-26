//
//  HealthKitManager.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation
import HealthKit
import Observation

/// Manages HealthKit integration for syncing workout data.
/// Uses iOS 17+ async/await patterns for querying workout samples.
@Observable
final class HealthKitManager {
    // MARK: - Published State
    
    /// Current authorization status for workouts
    private(set) var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    /// Whether HealthKit is available on this device
    private(set) var isAvailable: Bool = false
    
    /// Whether a sync operation is in progress
    private(set) var isSyncing: Bool = false
    
    /// Last error encountered during operations
    private(set) var lastError: Error?
    
    // MARK: - Private Properties
    
    private let healthStore = HKHealthStore()
    
    /// The workout type we're interested in reading
    private let workoutType = HKWorkoutType.workoutType()
    
    // MARK: - Initialization
    
    init() {
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
    
    /// Request authorization to read workout data from HealthKit
    func requestAuthorization() async throws {
        guard isAvailable else {
            throw HealthKitError.notAvailable
        }
        
        let typesToRead: Set<HKObjectType> = [workoutType]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        
        // Update status after request
        checkAuthorizationStatus()
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

// MARK: - Error Types

extension HealthKitManager {
    enum HealthKitError: LocalizedError {
        case notAvailable
        case authorizationDenied
        case queryFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device."
            case .authorizationDenied:
                return "Permission to access workout data was denied."
            case .queryFailed(let error):
                return "Failed to fetch workouts: \(error.localizedDescription)"
            }
        }
    }
}
