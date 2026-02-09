//
//  CardioModeSelectionView.swift
//  LifeFlow
//
//  Created by Fez Qazi on 1/10/26.
//

import SwiftUI

/// Mode selection sheet for cardio exercises
struct CardioModeSelectionView: View {
    let exerciseName: String
    let onSelectMode: (CardioWorkoutMode) -> Void
    @Environment(\.gymModeManager) private var gymModeManager
    
    @State private var selectedMode: CardioWorkoutMode? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                
                Text(exerciseName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("How would you like to work out?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            
            // Mode options - stacked for 3 options
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    ModeCard(
                        mode: .timed,
                        icon: "timer",
                        title: "Timed",
                        description: "Set a fixed duration",
                        isSelected: selectedMode == .timed,
                        onTap: { selectedMode = .timed }
                    )
                    
                    ModeCard(
                        mode: .freestyle,
                        icon: "waveform.path.ecg",
                        title: "Freestyle",
                        description: "Go at your own pace",
                        isSelected: selectedMode == .freestyle,
                        onTap: { selectedMode = .freestyle }
                    )
                }
                
                ModeCard(
                    mode: .distance,
                    icon: "figure.run",
                    title: "Distance",
                    description: "Target a specific distance",
                    isSelected: selectedMode == .distance,
                    onTap: { selectedMode = .distance }
                )
            }
            .padding(.horizontal)
            
            if selectedMode == .distance {
                HStack(spacing: 0) {
                    locationOption(title: "Outdoors", icon: "map.fill", isIndoor: false)
                    locationOption(title: "Treadmill", icon: "house.fill", isIndoor: true)
                }
                .padding(4)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Start button
            Button {
                if let mode = selectedMode {
                    onSelectMode(mode)
                }
            } label: {
                HStack {
                    Image(systemName: selectedMode == .timed ? "play.fill" : "figure.run")
                        .font(.title3)
                    Text("Start Workout")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    selectedMode == nil
                        ? AnyShapeStyle(Color.gray.gradient)
                        : AnyShapeStyle(Color.green.gradient),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedMode == nil)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
    
    private func locationOption(title: String, icon: String, isIndoor: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                gymModeManager.isIndoorRun = isIndoor
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(gymModeManager.isIndoorRun == isIndoor ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.clear)
                if gymModeManager.isIndoorRun == isIndoor {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isIndoor ? Color.orange.gradient : Color.cyan.gradient)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode Card

private struct ModeCard: View {
    let mode: CardioWorkoutMode
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void
    
    private var accentColor: Color {
        switch mode {
        case .timed: return .cyan
        case .freestyle: return .orange
        case .distance: return .purple
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundStyle(accentColor)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? accentColor.opacity(0.1) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? accentColor : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

#Preview {
    CardioModeSelectionView(exerciseName: "Treadmill") { mode in
        print("Selected: \(mode)")
    }
}
