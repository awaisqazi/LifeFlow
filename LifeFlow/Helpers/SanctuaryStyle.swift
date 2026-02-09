//
//  SanctuaryStyle.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI

enum SanctuaryPhase {
    case dawn
    case day
    case dusk
    case night
}

struct SanctuaryPalette {
    let gradient: [Color]
    let glow: Color
    let label: String
}

enum SanctuaryStyle {
    static func phase(for date: Date = .now) -> SanctuaryPhase {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .dawn
        case 11..<17: return .day
        case 17..<21: return .dusk
        default: return .night
        }
    }

    static func palette(for phase: SanctuaryPhase) -> SanctuaryPalette {
        switch phase {
        case .dawn:
            return SanctuaryPalette(
                gradient: [
                    Color(red: 0.07, green: 0.22, blue: 0.30),
                    Color(red: 0.19, green: 0.31, blue: 0.45),
                    Color(red: 0.32, green: 0.24, blue: 0.38)
                ],
                glow: Color.orange.opacity(0.5),
                label: "Dawn"
            )
        case .day:
            return SanctuaryPalette(
                gradient: [
                    Color(red: 0.03, green: 0.17, blue: 0.30),
                    Color(red: 0.05, green: 0.25, blue: 0.40),
                    Color(red: 0.12, green: 0.32, blue: 0.46)
                ],
                glow: Color.cyan.opacity(0.52),
                label: "Day"
            )
        case .dusk:
            return SanctuaryPalette(
                gradient: [
                    Color(red: 0.08, green: 0.11, blue: 0.24),
                    Color(red: 0.18, green: 0.13, blue: 0.31),
                    Color(red: 0.30, green: 0.17, blue: 0.25)
                ],
                glow: Color.purple.opacity(0.5),
                label: "Dusk"
            )
        case .night:
            return SanctuaryPalette(
                gradient: [
                    Color(red: 0.01, green: 0.05, blue: 0.12),
                    Color(red: 0.03, green: 0.08, blue: 0.20),
                    Color(red: 0.07, green: 0.09, blue: 0.22)
                ],
                glow: Color.indigo.opacity(0.48),
                label: "Night"
            )
        }
    }

    static func greeting(for date: Date = .now) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Ready to flow this morning?"
        case 12..<17: return "Ready to keep momentum?"
        case 17..<22: return "Ready to close strong tonight?"
        default: return "Ready to reset and recover?"
        }
    }
}

struct SanctuaryHeaderView: View {
    let title: String
    let subtitle: String
    let kicker: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kicker.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.system(size: 46, weight: .bold, design: .serif))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.76)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct SanctuaryTimeBackdrop: View {
    var includeMeshOverlay: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 30)) { context in
            let phase = SanctuaryStyle.phase(for: context.date)
            let palette = SanctuaryStyle.palette(for: phase)

            ZStack {
                LinearGradient(
                    colors: palette.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [palette.glow, .clear],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 380
                )
                .blendMode(.screen)

                if includeMeshOverlay {
                    AnimatedMeshGradientView(theme: phase.meshTheme)
                        .opacity(reduceMotion ? 0.06 : 0.14)
                        .blur(radius: reduceMotion ? 20 : 36)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: palette.label)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension SanctuaryPhase {
    fileprivate var meshTheme: MeshGradientTheme {
        switch self {
        case .dawn: return .horizon
        case .day: return .flow
        case .dusk: return .temple
        case .night: return .temple
        }
    }
}

struct SanctuarySectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.58))

            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(height: 1)
        }
    }
}

extension View {
    /// Creates a subtle stream-depth effect for card stacks in Flow.
    func sanctuaryStreamDepth(index: Int, reduceMotion: Bool) -> some View {
        let depth = CGFloat(max(0, min(index, 4)))
        let scale: CGFloat = reduceMotion ? 1 : (1 - depth * 0.014)
        let opacity: Double = reduceMotion ? 1 : Double(1 - depth * 0.05)
        let yOffset: CGFloat = reduceMotion ? 0 : depth * 2.0

        return self
            .scaleEffect(scale)
            .opacity(opacity)
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(depth) * 0.9),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .offset(y: yOffset)
    }
}
