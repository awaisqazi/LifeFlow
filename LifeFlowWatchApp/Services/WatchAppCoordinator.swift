import Foundation
import Observation
import SwiftUI
import LifeFlowCore

@MainActor
@Observable
final class WatchAppCoordinator {
    enum Route {
        case dashboard
        case activeRun
        case summary
        case settings
    }

    var workoutManager = WatchWorkoutManager()

    var route: Route = .dashboard
    var preferredRunType: RunType = .base
    var isIndoorRun: Bool = false

    init() {
        loadPreferences()
    }

    func startRun() async {
        await workoutManager.startRun(style: preferredRunType, isIndoor: isIndoorRun)
        if workoutManager.lifecycleState == .running || workoutManager.lifecycleState == .paused {
            route = .activeRun
        }
    }

    func endRun() async {
        await workoutManager.endRun(discarded: false)
        route = .summary
    }

    func discardRun() async {
        await workoutManager.endRun(discarded: true)
        route = .dashboard
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active {
            Task { @MainActor in
                await workoutManager.applyPendingIntentActions()
                syncRouteFromRunState()
            }
        }
    }

    func syncRouteFromRunState() {
        switch workoutManager.lifecycleState {
        case .running, .paused, .preparing:
            route = .activeRun
        case .ended:
            route = .summary
        case .idle:
            if route != .settings {
                route = .dashboard
            }
        }
    }

    func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(preferredRunType.rawValue, forKey: "watch.preferredRunType")
        defaults.set(isIndoorRun, forKey: "watch.isIndoorRun")
    }

    private func loadPreferences() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "watch.preferredRunType"),
           let runType = RunType(rawValue: raw) {
            preferredRunType = runType
        }

        isIndoorRun = defaults.bool(forKey: "watch.isIndoorRun")
    }
}
