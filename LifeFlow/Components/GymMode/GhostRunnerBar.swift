//
//  GhostRunnerBar.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI

struct GhostRunnerBar: View {
    var progress: Double
    var ghostProgress: Double

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var clampedGhostProgress: Double {
        min(max(ghostProgress, 0), 1)
    }

    private var runnerColor: Color {
        clampedProgress >= clampedGhostProgress ? .green : .orange
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))

                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: geometry.size.width * clampedGhostProgress)

                Capsule()
                    .fill(runnerColor.gradient)
                    .frame(width: geometry.size.width * clampedProgress)
                    .shadow(color: runnerColor.opacity(0.6), radius: 8)
            }
        }
        .frame(height: 12)
    }
}
