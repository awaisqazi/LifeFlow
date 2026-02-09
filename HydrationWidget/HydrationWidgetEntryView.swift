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
            if !isAccented {
                Color(red: 0.04, green: 0.05, blue: 0.12)
            }

            liquidLayer

            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .containerBackground(for: .widget) {
            if isAccented {
                Color.clear
            } else {
                ZStack {
                    Color(red: 0.03, green: 0.04, blue: 0.1)
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.24),
                            Color.blue.opacity(0.20),
                            Color.indigo.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }

    private var liquidLayer: some View {
        GeometryReader { geo in
            ZStack {
                WidgetWave(progress: entry.progress, waveHeight: 0.028, phase: 1.55)
                    .fill(backWaveStyle)
                    .widgetAccentable()

                WidgetWave(progress: entry.progress, waveHeight: 0.045, phase: 0.2)
                    .fill(frontWaveStyle)
                    .overlay {
                        WidgetWave(progress: entry.progress, waveHeight: 0.045, phase: 0.2)
                            .stroke(Color.white.opacity(isAccented ? 0.32 : 0.24), lineWidth: 1)
                    }
                    .shadow(color: isAccented ? .clear : Color.cyan.opacity(0.30), radius: 10, x: 0, y: -4)
                    .widgetAccentable()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .mask(ContainerRelativeShape())
        .allowsHitTesting(false)
    }

    private var backWaveStyle: AnyShapeStyle {
        if isAccented {
            return AnyShapeStyle(Color.primary.opacity(0.18))
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.45),
                    Color.indigo.opacity(0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var frontWaveStyle: AnyShapeStyle {
        if isAccented {
            return AnyShapeStyle(Color.primary.opacity(0.7))
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.88),
                    Color.blue.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 7) {
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

            HStack(spacing: 8) {
                compactActionButton(amount: -8, icon: "minus")
                compactActionButton(amount: 8, icon: "plus")
                Spacer(minLength: 0)
            }
        }
        .padding(12)
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

                capsuleProgress
            }

            Spacer(minLength: 8)

            VStack(spacing: 9) {
                actionButton(amount: -8, icon: "minus", label: "-8")
                actionButton(amount: 8, icon: "cup.and.saucer.fill", label: "+8")
                actionButton(amount: 16, icon: "waterbottle.fill", label: "+16")
            }
            .frame(width: 66)
        }
        .padding(14)
    }

    private var capsuleProgress: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isAccented ? Color.primary.opacity(0.20) : Color.white.opacity(0.20))

                Capsule()
                    .fill(isAccented ? Color.primary : Color.white.opacity(0.88))
                    .frame(width: geo.size.width * max(0, min(entry.progress, 1)))
                    .widgetAccentable()
            }
        }
        .frame(height: 11)
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
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(isAccented ? Color.primary.opacity(0.18) : Color.white.opacity(0.18))
                        .overlay {
                            Circle()
                                .stroke(
                                    isAccented ? Color.primary.opacity(0.35) : Color.white.opacity(0.24),
                                    lineWidth: 1
                                )
                        }
                        .widgetAccentable()
                }
        }
        .buttonStyle(.plain)
    }
}
