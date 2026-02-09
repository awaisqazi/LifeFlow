//
//  WorkoutSourceBadge.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI

struct WorkoutSourceBadge: View {
    let sourceName: String
    let bundleID: String
    let isNative: Bool

    private var iconName: String {
        if isNative {
            return "drop.fill"
        }

        let loweredName = sourceName.lowercased()
        let loweredBundle = bundleID.lowercased()
        if loweredName.contains("apple") || loweredBundle.contains("apple") {
            return "apple.logo"
        }
        if loweredName.contains("strava") || loweredBundle.contains("strava") {
            return "figure.outdoor.cycle"
        }
        return "link"
    }

    private var accent: Color {
        isNative ? .cyan : .secondary
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))

            Text(sourceName.isEmpty ? "Unknown Source" : sourceName)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(accent.opacity(0.24), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 10) {
        WorkoutSourceBadge(sourceName: "LifeFlow", bundleID: "com.fezqazi.lifeflow", isNative: true)
        WorkoutSourceBadge(sourceName: "Apple Watch", bundleID: "com.apple.workout", isNative: false)
        WorkoutSourceBadge(sourceName: "Strava", bundleID: "com.strava.run", isNative: false)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
