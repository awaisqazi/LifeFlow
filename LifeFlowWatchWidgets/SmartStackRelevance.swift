import Foundation
import WidgetKit
import CoreLocation
import LifeFlowCore

/// Provides advanced relevance signals for Smart Stack promotion
struct SmartStackRelevanceProvider {
    
    /// Create relevance based on current state and context
    static func relevance(
        for state: WatchWidgetState,
        currentDate: Date = Date(),
        currentLocation: CLLocation? = nil
    ) -> TimelineEntryRelevance? {
        
        // Active workout: Maximum relevance
        if state.lifecycleState == .running || state.lifecycleState == .paused {
            return TimelineEntryRelevance(score: 100, duration: 3600)
        }
        
        // Preparing: High relevance
        if state.lifecycleState == .preparing {
            return TimelineEntryRelevance(score: 80, duration: 600)
        }
        
        // Recently completed: Moderate relevance
        if state.lifecycleState == .ended {
            let timeSinceUpdate = currentDate.timeIntervalSince(state.lastUpdated)
            if timeSinceUpdate < 600 { // Within 10 minutes
                return TimelineEntryRelevance(score: 60, duration: 300)
            }
            return TimelineEntryRelevance(score: 20, duration: 1800)
        }
        
        // Time-based relevance for idle state
        return timeBasedRelevance(currentDate: currentDate)
    }
    
    /// Calculate relevance based on typical workout times
    private static func timeBasedRelevance(currentDate: Date) -> TimelineEntryRelevance? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentDate)
        let weekday = calendar.component(.weekday, from: currentDate)
        
        // Weekend mornings (6-10 AM): Higher relevance for long runs
        if (weekday == 1 || weekday == 7) && (6...10).contains(hour) {
            return TimelineEntryRelevance(score: 50, duration: 7200)
        }
        
        // Weekday early mornings (5-8 AM): Moderate relevance
        if (2...6).contains(weekday) && (5...8).contains(hour) {
            return TimelineEntryRelevance(score: 40, duration: 3600)
        }
        
        // Weekday evenings (5-8 PM): Moderate relevance
        if (2...6).contains(weekday) && (17...20).contains(hour) {
            return TimelineEntryRelevance(score: 40, duration: 3600)
        }
        
        // Off-peak times: Low relevance
        return TimelineEntryRelevance(score: 10, duration: 14400)
    }
    
    /// Donate activity for Smart Stack learning
    static func donateWorkoutActivity(
        lifecycleState: WatchRunLifecycleState,
        location: CLLocation? = nil
    ) {
        // Create activity attributes for Smart Stack learning
        let activityAttributes: [String: Any] = [
            "activity_type": "running",
            "lifecycle_state": lifecycleState.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // In a real implementation, you would use NSUserActivity
        // to donate this activity to the system
        let activity = NSUserActivity(activityType: "com.Fez.LifeFlow.workout")
        activity.title = "LifeFlow Run"
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = "lifeflow-workout-\(UUID().uuidString)"
        
        // Add location if available for geofencing
        if let location = location {
            activity.addUserInfoEntries(from: [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ])
        }
        
        activity.becomeCurrent()
    }
}
