//
//  TreadmillRunnerView.swift
//  LifeFlow
//
//  Created by Antigravity on 2/13/26.
//

import SwiftUI

/// Immersive full-screen treadmill experience for indoor runs.
/// Features cinematic mesh sky, volumetric moon glow, twinkling stars,
/// pace-driven parallax skyline, and an animated runner foreground.
struct TreadmillRunnerView: View {
    let currentDistance: Double
    let targetDistance: Double
    let speed: Double
    let elapsedTime: TimeInterval
    let formattedPace: String
    let formattedTime: String
    let ghostProgress: Double
    let ghostDeltaLabel: String
    let ghostDelta: Double
    let showGhostRunner: Bool

    @Environment(\.scenePhase) private var scenePhase
    #if os(watchOS)
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    #endif

    @State private var displayedMilestone: MilestoneData?
    @State private var passedMilestones: Set<Int> = []

    private var progress: Double {
        guard targetDistance > 0 else { return 0 }
        return min(1.0, currentDistance / targetDistance)
    }

    /// Normalized treadmill speed used to drive parallax and animation intensity.
    private var normalizedSpeed: Double {
        min(1.6, max(0.35, speed / 6.0))
    }

    /// Approximate running cadence in Hz (steps/second) derived from speed.
    private var cadenceHz: Double {
        let stepsPerMinute = max(95, min(220, speed * 155))
        return stepsPerMinute / 60.0
    }

    private var paceSecondsPerMile: Double {
        guard speed > 0.1 else { return 0 }
        return 3600 / speed
    }

    private var isSceneAnimating: Bool {
        #if os(watchOS)
        return scenePhase == .active && !isLuminanceReduced
        #else
        return scenePhase == .active
        #endif
    }

    struct MilestoneData: Equatable {
        let percent: Int
        let label: String
        let icon: String
    }

    var body: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            let topHUDHorizontalInset: CGFloat = 12
            let topHUDWidth = max(200, min(geo.size.width - (topHUDHorizontalInset * 2), 760))
            let runnerBottomPadding = max(geo.safeAreaInsets.bottom + 188, geo.size.height * 0.22)
            let topHUDPadding = max(topInset + 8, 48)

            ZStack {
                // MARK: - Environment Layer (ignores safe area)
                environmentLayer(geo: geo)

                // MARK: - Foreground Runner (respects safe area implicitly)
                RunnerForegroundView(
                    speed: speed,
                    cadenceHz: cadenceHz,
                    ghostDelta: ghostDelta,
                    showGhostRunner: showGhostRunner,
                    isAnimating: isSceneAnimating
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, runnerBottomPadding)

                if let milestone = displayedMilestone {
                    VStack {
                        Spacer()
                            .frame(height: geo.size.height * 0.24)
                        MilestoneToast(milestone: milestone.label, icon: milestone.icon)
                        Spacer()
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .overlay(alignment: .top) {
                VStack(spacing: 10) {
                    RunStatusStrip(
                        formattedPace: formattedPace,
                        formattedTime: formattedTime,
                        ghostDeltaLabel: ghostDeltaLabel,
                        showGhostRunner: showGhostRunner
                    )

                    MiniDistanceBar(
                        progress: progress,
                        currentMiles: currentDistance,
                        targetMiles: targetDistance,
                        ghostProgress: ghostProgress
                    )
                }
                .frame(width: topHUDWidth)
                .padding(.top, topHUDPadding)
                .padding(.horizontal, topHUDHorizontalInset)
            }
        }
        .onChange(of: currentDistance) { _, newDistance in
            checkMilestones(distance: newDistance)
        }
    }

    // MARK: - Environment Layer

    @ViewBuilder
    private func environmentLayer(geo: GeometryProxy) -> some View {
        AnimatedMeshGradientView(
            theme: .horizon,
            animationSpeed: 0.18 + (normalizedSpeed * 0.2)
        )
        .ignoresSafeArea()

        LinearGradient(
            colors: [
                Color.black.opacity(0.28),
                Color(red: 0.04, green: 0.03, blue: 0.08).opacity(0.68)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        Image("texture_noise_grain")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .blendMode(.overlay)
            .opacity(0.3)
            .allowsHitTesting(false)

        TwinklingStarsView(
            isAnimating: isSceneAnimating,
            progress: progress
        )
        .blendMode(.screen)

        MoonBeaconView(progress: progress)
            .offset(
                x: geo.size.width * 0.32,
                y: -geo.size.height * (0.28 - (0.08 * progress))
            )
            .blendMode(.screen)

        CityscapeParallaxView(
            scrollSpeed: CGFloat(normalizedSpeed),
            paceSecondsPerMile: paceSecondsPerMile,
            isAnimating: isSceneAnimating
        )
        .ignoresSafeArea()
    }

    private func checkMilestones(distance: Double) {
        guard targetDistance > 0 else { return }
        let pct = Int((distance / targetDistance) * 100)

        let milestones: [(Int, String, String)] = [
            (25, "25% - Quarter Locked", "flame.fill"),
            (50, "50% - Midpoint Achieved", "bolt.fill"),
            (75, "75% - Final Push", "hare.fill"),
            (100, "100% - Run Complete", "star.fill")
        ]

        for (threshold, label, icon) in milestones {
            if pct >= threshold && !passedMilestones.contains(threshold) {
                passedMilestones.insert(threshold)

                let data = MilestoneData(percent: threshold, label: label, icon: icon)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    displayedMilestone = data
                }

                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(threshold == 100 ? .success : .warning)
                #endif

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeOut(duration: 0.28)) {
                        if displayedMilestone == data {
                            displayedMilestone = nil
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Cityscape

private struct CityscapeParallaxView: View {
    let scrollSpeed: CGFloat
    let paceSecondsPerMile: Double
    let isAnimating: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Background layer — heavy blur, low opacity, atmospheric haze
                SkylineLayerCanvas(
                    layer: .back,
                    scrollSpeed: scrollSpeed,
                    isAnimating: isAnimating
                )
                .offset(y: -geo.size.height * 0.23)
                .blur(radius: 6)
                .opacity(0.45)

                // Midground layer — slight blur, medium opacity
                SkylineLayerCanvas(
                    layer: .mid,
                    scrollSpeed: scrollSpeed,
                    isAnimating: isAnimating
                )
                .offset(y: -geo.size.height * 0.16)
                .blur(radius: 2)
                .opacity(0.65)

                // Foreground layer — sharp, darkest silhouettes
                SkylineLayerCanvas(
                    layer: .front,
                    scrollSpeed: scrollSpeed,
                    isAnimating: isAnimating
                )
                .offset(y: -geo.size.height * 0.085)
                .opacity(0.92)

                // Treadmill floor
                TreadmillFloorView(
                    scrollSpeed: scrollSpeed,
                    paceSecondsPerMile: paceSecondsPerMile,
                    isAnimating: isAnimating
                )
                .frame(height: geo.size.height * 0.2)
            }
            // Fade the bottom of the cityscape so it dissolves into the background
            // rather than having a hard cutoff behind the dashboard.
            .mask(
                VStack(spacing: 0) {
                    Rectangle() // top portion fully visible
                    LinearGradient(
                        colors: [.white, .white.opacity(0.5), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.18)
                }
            )
        }
    }
}

private struct TreadmillFloorView: View {
    let scrollSpeed: CGFloat
    let paceSecondsPerMile: Double
    let isAnimating: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isAnimating)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let laneShift = (CGFloat(t) * scrollSpeed * 120)
            let wrapped = laneShift.truncatingRemainder(dividingBy: 88)
            let pulse = 0.5 + (0.5 * sin(t * 2.2))

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.72),
                                Color.black.opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Canvas(rendersAsynchronously: true) { context, size in
                    // Perspective lane strips
                    var x = -wrapped - 140
                    while x < size.width + 160 {
                        let path = RoundedRectangle(cornerRadius: 1.5)
                            .path(in: CGRect(x: x, y: size.height * 0.22, width: 30, height: 2.4))
                        context.fill(path, with: .color(.white.opacity(0.18)))
                        x += 88
                    }

                    // Moving sheen tied to pace and speed.
                    let sheenWidth = max(80, size.width * 0.28)
                    let paceFactor = paceSecondsPerMile > 0 ? CGFloat(max(0.55, min(1.5, 520 / paceSecondsPerMile))) : 1.0
                    let sheenX = (laneShift * 0.48 * paceFactor).truncatingRemainder(dividingBy: size.width + sheenWidth) - sheenWidth
                    let sheenRect = CGRect(x: sheenX, y: 0, width: sheenWidth, height: size.height)
                    context.fill(
                        Rectangle().path(in: sheenRect),
                        with: .linearGradient(
                            Gradient(colors: [
                                .clear,
                                Color.cyan.opacity(0.08 + (pulse * 0.06)),
                                .clear
                            ]),
                            startPoint: CGPoint(x: sheenRect.minX, y: sheenRect.minY),
                            endPoint: CGPoint(x: sheenRect.maxX, y: sheenRect.maxY)
                        )
                    )
                }

                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 24)
            }
        }
    }
}

private struct SkylineLayerCanvas: View {
    enum Layer {
        case back
        case mid
        case front

        var buildingCount: Int {
            switch self {
            case .back: return 34
            case .mid: return 26
            case .front: return 20
            }
        }

        var minHeight: CGFloat {
            switch self {
            case .back: return 50
            case .mid: return 86
            case .front: return 124
            }
        }

        var maxHeight: CGFloat {
            switch self {
            case .back: return 156
            case .mid: return 236
            case .front: return 304
            }
        }

        var minWidth: CGFloat {
            switch self {
            case .back: return 24
            case .mid: return 30
            case .front: return 34
            }
        }

        var maxWidth: CGFloat {
            switch self {
            case .back: return 58
            case .mid: return 70
            case .front: return 86
            }
        }

        var spacing: CGFloat {
            switch self {
            case .back: return 48
            case .mid: return 56
            case .front: return 66
            }
        }

        var velocityMultiplier: CGFloat {
            switch self {
            case .back: return 0.22
            case .mid: return 0.48
            case .front: return 0.82
            }
        }

        /// Deep midnight-blue monolithic silhouette colors.
        /// Back is lightest (atmospheric haze), front is near-black.
        var bodyColor: Color {
            switch self {
            case .back: return Color(red: 0.10, green: 0.11, blue: 0.22)
            case .mid:  return Color(red: 0.06, green: 0.06, blue: 0.15)
            case .front: return Color(red: 0.02, green: 0.02, blue: 0.07)
            }
        }

        /// Subtle roof highlight opacity per layer.
        var roofHighlightOpacity: Double {
            switch self {
            case .back: return 0.06
            case .mid:  return 0.10
            case .front: return 0.14
            }
        }
    }

    let layer: Layer
    let scrollSpeed: CGFloat
    let isAnimating: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 50.0, paused: !isAnimating)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas(rendersAsynchronously: true) { context, size in
                let cycle = max(size.width * 1.35, layer.spacing * CGFloat(layer.buildingCount))
                let travel = CGFloat(time) * scrollSpeed * layer.velocityMultiplier * 88
                let wrapped = travel.truncatingRemainder(dividingBy: cycle)

                for index in 0..<(layer.buildingCount * 2) {
                    let width = lerp(layer.minWidth, layer.maxWidth, hash(index, salt: 11))
                    let height = lerp(layer.minHeight, layer.maxHeight, hash(index, salt: 23))
                    let baseX = (CGFloat(index) * layer.spacing) - wrapped - cycle

                    if baseX > size.width + width || baseX + width < -width {
                        continue
                    }

                    let rect = CGRect(
                        x: baseX,
                        y: size.height - height,
                        width: width,
                        height: height
                    )

                    // Monolithic silhouette — no windows
                    context.fill(Rectangle().path(in: rect), with: .color(layer.bodyColor))

                    // Subtle roof edge highlight
                    let roof = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1)
                    context.fill(Rectangle().path(in: roof), with: .color(.white.opacity(layer.roofHighlightOpacity)))

                    // Occasional subtle vertical accent line for architectural detail
                    if hash(index, salt: 41) > 0.55 {
                        let accentX = rect.minX + (rect.width * lerp(0.25, 0.75, hash(index, salt: 53)))
                        let accentHeight = rect.height * lerp(0.3, 0.85, hash(index, salt: 67))
                        let accentRect = CGRect(
                            x: accentX,
                            y: rect.maxY - accentHeight,
                            width: 1,
                            height: accentHeight
                        )
                        context.fill(
                            Rectangle().path(in: accentRect),
                            with: .color(.white.opacity(0.03))
                        )
                    }
                }
            }
        }
    }

    private func hash(_ value: Int, salt: Int) -> CGFloat {
        let input = Double((value + 1) * (salt + 17))
        let raw = sin(input * 12.9898) * 43758.5453
        return CGFloat(raw - floor(raw))
    }

    private func lerp(_ minValue: CGFloat, _ maxValue: CGFloat, _ t: CGFloat) -> CGFloat {
        minValue + ((maxValue - minValue) * t)
    }
}

// MARK: - Sky Details

private struct TwinklingStarsView: View {
    let isAnimating: Bool
    let progress: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isAnimating)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas(rendersAsynchronously: true) { context, size in
                let starCount = 130
                let fade = max(0.22, 1.0 - (progress * 0.72))

                for index in 0..<starCount {
                    let x = hash(index, salt: 3) * size.width
                    let y = hash(index, salt: 7) * size.height * 0.52
                    let radius = 0.6 + (hash(index, salt: 19) * 1.7)
                    let phase = hash(index, salt: 31) * .pi * 2
                    let twinkleSpeed = 0.65 + (hash(index, salt: 47) * 1.9)
                    let twinkle = 0.35 + (0.65 * (0.5 + (0.5 * sin((t * twinkleSpeed) + phase))))

                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(.white.opacity(Double(twinkle * fade)))
                    )
                }
            }
        }
    }

    private func hash(_ value: Int, salt: Int) -> CGFloat {
        let input = Double((value + 5) * (salt + 41))
        let raw = sin(input * 78.233) * 43758.5453
        return CGFloat(raw - floor(raw))
    }
}

private struct MoonBeaconView: View {
    let progress: Double

    var body: some View {
        ZStack {
            // Outermost atmospheric glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color(red: 0.53, green: 0.69, blue: 1.0).opacity(0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .blendMode(.screen)

            // Secondary halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.53, green: 0.69, blue: 1.0).opacity(0.14),
                            Color(red: 0.53, green: 0.69, blue: 1.0).opacity(0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .blendMode(.screen)

            // Inner bright core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.96),
                            Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.6),
                            Color(red: 0.75, green: 0.85, blue: 1.0).opacity(0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 56
                    )
                )
                .frame(width: 112, height: 112)
                .blendMode(.screen)
        }
        .opacity(0.82 - (progress * 0.2))
    }
}

// MARK: - Foreground Runner

private struct RunnerForegroundView: View {
    let speed: Double
    let cadenceHz: Double
    let ghostDelta: Double
    let showGhostRunner: Bool
    let isAnimating: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isAnimating)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let bobAmplitude = min(8.0, 2.4 + (speed * 0.9))
            let bob = sin(t * cadenceHz * .pi * 2) * bobAmplitude
            let trailPulse = 0.4 + (0.6 * (0.5 + (0.5 * sin(t * 6))))

            ZStack {
                // Soft floor reflection — elliptical ground glow
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.35),
                                Color.cyan.opacity(0.12),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 40
                        )
                    )
                    .frame(width: 70, height: 8)
                    .blur(radius: 6)
                    .offset(y: 50)

                // Motion trail particles at high speed
                if speed > 2.8 {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(Color.cyan.opacity((0.06 + (0.08 * trailPulse)) * Double(4 - index) / 4.0))
                            .frame(width: CGFloat(42 + (index * 24)), height: 4)
                            .offset(x: CGFloat(-62 - (index * 22)), y: CGFloat(-6 + (index * 12)))
                            .blur(radius: 1.2)
                    }
                }

                // Ghost runner
                if showGhostRunner {
                    Image(systemName: "figure.run")
                        .font(.system(size: 50, weight: .thin, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.17))
                        .shadow(color: .white.opacity(0.08), radius: 10)
                        .offset(x: min(max(CGFloat(ghostDelta) * 58, -132), 132), y: bob + 6)
                        .blur(radius: 0.5)
                }

                // Primary runner
                Image(systemName: "figure.run")
                    .font(.system(size: 84, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.82, green: 0.95, blue: 1.0),
                                Color.cyan.opacity(0.82)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    // Stacked glow: tight white core + diffuse cyan halo
                    .shadow(color: .white.opacity(0.8), radius: 4)
                    .shadow(color: .cyan.opacity(0.4), radius: 15)
                    .shadow(color: .cyan.opacity(0.18), radius: 40, y: 8)
                    .offset(y: bob)
            }
        }
    }
}

// MARK: - Top HUD

private struct RunStatusStrip: View {
    let formattedPace: String
    let formattedTime: String
    let ghostDeltaLabel: String
    let showGhostRunner: Bool

    var body: some View {
        HStack(spacing: 8) {
            Label(formattedPace, systemImage: "gauge.with.dots.needle.67percent")
                .foregroundStyle(.white)
            Spacer(minLength: 4)
            Label(formattedTime, systemImage: "timer")
                .foregroundStyle(.white)

            if showGhostRunner {
                Spacer(minLength: 4)
                Label(ghostDeltaLabel, systemImage: "figure.run")
                    .foregroundStyle(Color.cyan.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LiquidGlass.specularGradient,
                            lineWidth: LiquidGlass.strokeWidth
                        )
                        .blendMode(.overlay)
                )
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 18)
        }
        .shadow(
            color: LiquidGlass.shadowColor,
            radius: LiquidGlass.shadowRadius * 0.7,
            y: LiquidGlass.shadowY * 0.6
        )
    }
}

private struct MiniDistanceBar: View {
    let progress: Double
    let currentMiles: Double
    let targetMiles: Double
    let ghostProgress: Double

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.58, green: 0.92, blue: 0.96),
                                    Color(red: 0.36, green: 0.84, blue: 0.72)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(min(1.0, progress))))
                        .shadow(color: .cyan.opacity(0.65), radius: 8)

                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2.5, height: 9)
                        .offset(x: geo.size.width * CGFloat(min(1.0, ghostProgress)))

                    ForEach([0.25, 0.5, 0.75], id: \.self) { marker in
                        Circle()
                            .fill(progress >= marker ? .white : .white.opacity(0.22))
                            .frame(width: 5, height: 5)
                            .offset(x: geo.size.width * CGFloat(marker) - 2.5)
                    }
                }
            }
            .frame(height: 7)

            HStack {
                Text(String(format: "%.2f mi", currentMiles))
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: currentMiles))

                Spacer()

                Text(String(format: "%.1f mi", targetMiles))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LiquidGlass.specularGradient,
                            lineWidth: 1
                        )
                        .blendMode(.overlay)
                )
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(height: 1)
                .padding(.horizontal, 20)
        }
        .shadow(
            color: LiquidGlass.shadowColor,
            radius: LiquidGlass.shadowRadius * 0.55,
            y: LiquidGlass.shadowY * 0.5
        )
    }
}
