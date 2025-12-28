//
//  RestTimerLiveActivity.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import WidgetKit
import ActivityKit

/// Live Activity for rest timer displayed in Dynamic Island and Lock Screen.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock Screen/Banner presentation
            LockScreenRestTimerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded presentation
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.formattedTime)
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("REST")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        Text(context.attributes.exerciseName)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Next: Set \(context.attributes.nextSetNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        ProgressView(value: Double(context.attributes.totalDuration - context.state.timeRemaining),
                                     total: Double(context.attributes.totalDuration))
                            .tint(.orange)
                    }
                }
            } compactLeading: {
                // Compact leading (minimal presentation)
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                // Compact trailing (minimal presentation)
                Text(context.state.formattedTime)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.orange)
            } minimal: {
                // Minimal presentation (when combined with another activity)
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenRestTimerView: View {
    let context: ActivityViewContext<RestTimerAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("REST TIMER")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Text(context.attributes.exerciseName)
                        .font(.subheadline.weight(.medium))
                }
                
                Spacer()
                
                Text(context.state.formattedTime)
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(.orange)
            }
            
            // Progress bar
            ProgressView(value: Double(context.attributes.totalDuration - context.state.timeRemaining),
                         total: Double(context.attributes.totalDuration))
                .tint(.orange)
            
            Text("Next: Set \(context.attributes.nextSetNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
        .activitySystemActionForegroundColor(.orange)
    }
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: RestTimerAttributes(exerciseName: "Bench Press", nextSetNumber: 2, totalDuration: 60)) {
    RestTimerLiveActivity()
} contentStates: {
    RestTimerAttributes.ContentState(timeRemaining: 45, isPaused: false)
}

#Preview("Lock Screen", as: .content, using: RestTimerAttributes(exerciseName: "Bench Press", nextSetNumber: 2, totalDuration: 60)) {
    RestTimerLiveActivity()
} contentStates: {
    RestTimerAttributes.ContentState(timeRemaining: 45, isPaused: false)
}
