//
//  CardioWorkoutView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 1/10/26.
//

import SwiftUI

/// Main orchestrator view for cardio workouts
/// Handles mode selection and routes to Timed or Freestyle views
struct CardioWorkoutView: View {
    let exercise: WorkoutExercise
    let onComplete: (TimeInterval, Double, Double, [CardioInterval]?) -> Void
    let onCancel: () -> Void
    
    @State private var selectedMode: CardioWorkoutMode? = nil
    @State private var showModeSelection: Bool = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showModeSelection {
                CardioModeSelectionView(
                    exerciseName: exercise.name,
                    onSelectMode: { mode in
                        selectedMode = mode
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showModeSelection = false
                        }
                    }
                )
                .transition(.opacity)
            } else if let mode = selectedMode {
                switch mode {
                case .timed:
                    TimedCardioView(
                        exerciseName: exercise.name,
                        onComplete: { duration, speed, incline in
                            onComplete(duration, speed, incline, nil)
                        },
                        onCancel: {
                            withAnimation {
                                showModeSelection = true
                                selectedMode = nil
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case .freestyle:
                    FreestyleCardioView(
                        exerciseName: exercise.name,
                        onComplete: { duration, avgSpeed, avgIncline, intervals in
                            onComplete(duration, avgSpeed, avgIncline, intervals)
                        },
                        onCancel: {
                            withAnimation {
                                showModeSelection = true
                                selectedMode = nil
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showModeSelection)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedMode)
    }
}

#Preview {
    let exercise = WorkoutExercise(name: "Treadmill", type: .cardio)
    
    return CardioWorkoutView(
        exercise: exercise,
        onComplete: { _, _, _, _ in },
        onCancel: { }
    )
}
