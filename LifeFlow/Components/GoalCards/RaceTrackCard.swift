//
//  RaceTrackCard.swift
//  LifeFlow
//
//  Created by Fez Qazi on 2/7/26.
//

import SwiftUI

/// Topographical course map visualization for the Horizon tab.
/// Shows training progress as a winding path that fills with color.
struct RaceTrackCard: View {
    let plan: TrainingPlan
    let status: TrainingStatus

    private var progress: Double {
        plan.progressPercentage
    }

    private var statusColor: Color {
        switch status {
        case .onTrack: return .green
        case .struggling: return .orange
        case .crushingIt: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.raceDistance.displayName)
                        .font(.headline)
                    Text(plan.currentPhase.displayName + " Phase")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Confidence badge
                VStack(spacing: 2) {
                    Text("\(Int(plan.confidenceScore * 100))%")
                        .font(.title3.bold())
                        .foregroundStyle(statusColor)
                    Text("Ready")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Course map visualization
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background path (greyed out)
                    RaceTrackShape()
                        .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 6, lineCap: .round))

                    // Filled progress path with Liquid Fill
                    RaceTrackShape()
                        .trim(from: 0, to: progress)
                        .stroke(
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .overlay {
                            // The actual liquid content, masked to the trimmed shape
                            AnimatedMeshGradientView(theme: meshTheme)
                                .scaleEffect(1.2)
                                .mask {
                                    RaceTrackShape()
                                        .trim(from: 0, to: progress)
                                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                }
                        }
                        .animation(.spring(response: 0.6), value: progress)
                        .shadow(color: statusColor.opacity(0.3), radius: 4)

                    // Milestone markers
                    ForEach(milestones, id: \.position) { milestone in
                        Circle()
                            .fill(milestone.position <= progress ? statusColor : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .position(
                                x: geo.size.width * milestone.position,
                                y: yPosition(for: milestone.position, in: geo.size)
                            )
                    }

                    // Current position indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )
                        .shadow(color: statusColor.opacity(0.5), radius: 4)
                        .position(
                            x: geo.size.width * progress,
                            y: yPosition(for: progress, in: geo.size)
                        )
                        .animation(.spring(response: 0.6), value: progress)

                    // Finish flag
                    Image(systemName: "flag.checkered")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .position(
                            x: geo.size.width - 8,
                            y: yPosition(for: 1.0, in: geo.size) - 16
                        )
                }
            }
            .frame(height: 60)

            // Next milestone floating label
            if let nextSession = plan.todaysSession, nextSession.runType != .rest {
                HStack(spacing: 8) {
                    Image(systemName: nextSession.runType.icon)
                        .foregroundStyle(statusColor)
                    Text("\(nextSession.runType.displayName): \(String(format: "%.1f", nextSession.targetDistance)) mi")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor)
                }
            }

            Divider()

            // Stats row
            HStack {
                StatItem(title: "Week", value: "\(plan.currentWeek)/\(plan.totalWeeks)", color: .primary)
                Spacer()
                StatItem(title: "Day", value: "\(plan.currentDay)/\(plan.totalDays)", color: .primary)
                Spacer()
                StatItem(title: "Compliance", value: "\(Int(plan.complianceScore * 100))%", color: statusColor)
                Spacer()
                StatItem(title: "Status", value: status.label, color: statusColor)
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    // MARK: - Milestone Data

    private var milestones: [(position: Double, label: String)] {
        [
            (0.25, "25%"),
            (0.50, "Halfway"),
            (0.75, "75%"),
        ]
    }

    /// Calculate Y position on the winding path
    private func yPosition(for x: Double, in size: CGSize) -> Double {
        let midY = size.height / 2
        let amplitude = size.height * 0.3
        return midY + sin(x * .pi * 2.5) * amplitude
    }
    
    private var meshTheme: MeshGradientTheme {
        switch status {
        case .onTrack: return .flow
        case .struggling: return .temple
        case .crushingIt: return .horizon
        }
    }
}

// MARK: - Race Track Shape

/// A winding path shape representing the race course
struct RaceTrackShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let amplitude = rect.height * 0.3

        path.move(to: CGPoint(x: 0, y: midY))

        let steps = 50
        for i in 1...steps {
            let fraction = Double(i) / Double(steps)
            let x = rect.width * fraction
            let y = midY + sin(fraction * .pi * 2.5) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

#Preview {
    let plan = TrainingPlan(
        raceDistance: .halfMarathon,
        raceDate: Date().addingTimeInterval(86400 * 60),
        weeklyMileage: 15,
        longestRecentRun: 6
    )

    ScrollView {
        RaceTrackCard(plan: plan, status: .onTrack)
            .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
