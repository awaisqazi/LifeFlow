//
//  HydrationWidgetEntryView.swift
//  HydrationWidgetExtension
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import WidgetKit
import AppIntents

struct HydrationWidgetEntryView: View {
    let entry: SimpleEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    private var isAccented: Bool {
        widgetRenderingMode == .accented
    }

    private var headlineColor: Color {
        isAccented ? .primary : .white.opacity(0.78)
    }

    private var valueColor: Color {
        isAccented ? .primary : .white
    }

    private var secondaryTextColor: Color {
        isAccented ? .primary.opacity(0.82) : .white.opacity(0.82)
    }

    var body: some View {
        ZStack {
            baseGlassLayer
            liquidLayer
            glassChromeOverlay

            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .clipShape(ContainerRelativeShape())
        .compositingGroup()
        .containerBackground(for: .widget) {
            if isAccented {
                Color.clear
            } else {
                Color(red: 0.03, green: 0.04, blue: 0.09)
            }
        }
    }

    @ViewBuilder
    private var baseGlassLayer: some View {
        if isAccented {
            Color.clear
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.03, blue: 0.16),
                        Color(red: 0.02, green: 0.06, blue: 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.cyan.opacity(0.22),
                        .clear
                    ],
                    center: .bottomLeading,
                    startRadius: 22,
                    endRadius: 250
                )
            }
        }
    }

    @ViewBuilder
    private var glassChromeOverlay: some View {
        if !isAccented {
            ContainerRelativeShape()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.32),
                            .white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            LinearGradient(
                colors: [
                    .white.opacity(0.18),
                    .clear,
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
    }

    private var liquidLayer: some View {
        GeometryReader { geo in
            ZStack {
                WidgetWave(progress: entry.progress, waveHeight: 0.030, phase: 1.55)
                    .fill(backWaveStyle)
                    .widgetAccentable()

                WidgetWave(progress: entry.progress, waveHeight: 0.046, phase: 0.2)
                    .fill(frontWaveStyle)
                    .overlay {
                        WidgetWave(progress: entry.progress, waveHeight: 0.046, phase: 0.2)
                            .stroke(Color.white.opacity(isAccented ? 0.30 : 0.40), lineWidth: 1)
                    }
                    .shadow(color: isAccented ? .clear : Color.cyan.opacity(0.34), radius: 12, x: 0, y: -5)
                    .widgetAccentable()

                if !isAccented {
                    LinearGradient(
                        colors: [
                            .white.opacity(0.15),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: max(24, geo.size.height * 0.26))
                    .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .mask(ContainerRelativeShape())
        .allowsHitTesting(false)
    }

    private var backWaveStyle: AnyShapeStyle {
        if isAccented {
            return AnyShapeStyle(Color.primary.opacity(0.20))
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.54),
                    Color.indigo.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var frontWaveStyle: AnyShapeStyle {
        if isAccented {
            return AnyShapeStyle(Color.primary.opacity(0.72))
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.94),
                    Color.blue.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(headlineColor)
                Text("Hydration")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(headlineColor)
                    .textCase(.uppercase)
            }

            Spacer(minLength: 0)

            Text("\(Int((entry.progress * 100).rounded()))%")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(valueColor)
                .contentTransition(.numericText(value: entry.progress))
                .widgetAccentable()

            Text("\(Int(entry.waterIntake.rounded())) / \(Int(entry.dailyGoal.rounded())) oz")
                .font(.caption.weight(.medium))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)

            HStack(spacing: 10) {
                compactActionButton(amount: -8, icon: "minus")
                compactActionButton(amount: 8, icon: "plus")
                Spacer(minLength: 0)
            }
        }
        .padding(13)
    }

    private var mediumLayout: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "water.waves")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(headlineColor)
                    Text("Hydration")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(headlineColor)
                        .textCase(.uppercase)
                }

                Spacer(minLength: 2)

                Text("\(Int((entry.progress * 100).rounded()))%")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(valueColor)
                    .contentTransition(.numericText(value: entry.progress))
                    .widgetAccentable()

                Text("\(Int(entry.waterIntake.rounded())) of \(Int(entry.dailyGoal.rounded())) oz")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)

                goalStatusPill
            }

            Spacer(minLength: 8)

            VStack(spacing: 9) {
                actionButton(amount: -8, icon: "minus", label: "-8")
                actionButton(amount: 8, icon: "cup.and.saucer.fill", label: "+8")
                actionButton(amount: 16, icon: "waterbottle.fill", label: "+16")
            }
            .frame(width: 66)
        }
        .padding(16)
    }

    private var remainingOunces: Int {
        max(0, Int((entry.dailyGoal - entry.waterIntake).rounded()))
    }

    private var goalStatusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: remainingOunces == 0 ? "checkmark.circle.fill" : "drop.fill")
                .font(.caption.weight(.semibold))
                .widgetAccentable()

            Text(remainingOunces == 0 ? "Goal reached" : "\(remainingOunces) oz to goal")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(secondaryTextColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(isAccented ? Color.primary.opacity(0.18) : Color.white.opacity(0.14))
                .overlay {
                    Capsule()
                        .stroke(
                            isAccented ? Color.primary.opacity(0.26) : Color.white.opacity(0.18),
                            lineWidth: 1
                        )
                }
                .widgetAccentable()
        }
    }

    private func actionButton(amount: Double, icon: String, label: String) -> some View {
        Button(intent: LogWaterIntent(amount: amount)) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(valueColor)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(isAccented ? Color.primary.opacity(0.18) : Color.white.opacity(0.14))
                    .overlay {
                        Circle()
                            .stroke(
                                isAccented ? Color.primary.opacity(0.35) : Color.white.opacity(0.22),
                                lineWidth: 1
                            )
                    }
                    .widgetAccentable()
            }
        }
        .buttonStyle(.plain)
    }

    private func compactActionButton(amount: Double, icon: String) -> some View {
        Button(intent: LogWaterIntent(amount: amount)) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(valueColor)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(isAccented ? Color.primary.opacity(0.20) : Color.white.opacity(0.20))
                        .overlay {
                            Circle()
                                .stroke(
                                    isAccented ? Color.primary.opacity(0.36) : Color.white.opacity(0.28),
                                    lineWidth: 1
                                )
                        }
                        .widgetAccentable()
                }
        }
        .buttonStyle(.plain)
    }
}
