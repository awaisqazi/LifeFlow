//
//  GymWidgetsBundle.swift
//  GymWidgets
//
//  Created by Fez Qazi on 12/27/25.
//

import WidgetKit
import SwiftUI

@main
struct GymWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Home Screen Widget
        GymWidgets()
        
        // Control Center Widget
        GymWidgetsControl()
        
        // Live Activity for active workouts
        GymWorkoutLiveActivity()
    }
}
