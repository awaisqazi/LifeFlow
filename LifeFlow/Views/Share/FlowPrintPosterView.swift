//
//  FlowPrintPosterView.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI
import CoreLocation
import MapKit

struct FlowPrintPosterView: View {
    let input: FlowPrintRenderInput

    private var isStory: Bool {
        input.format == .story
    }

    private var visibleHighlights: [FlowPrintHighlight] {
        Array(input.highlights.prefix(4))
    }

    private var primaryTitleLine: String {
        let trimmed = input.sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? input.runLine : trimmed
    }

    private var secondaryTitleLine: String {
        if primaryTitleLine.caseInsensitiveCompare(input.runLine) == .orderedSame {
            return "\(input.durationLine) • \(input.templeLine)"
        }
        return "\(input.runLine) • \(input.durationLine) • \(input.templeLine)"
    }

    private var fallbackTitle: String {
        if input.runLine.lowercased().contains("run") {
            return "No GPS route, progress still captured"
        }
        return "Strength session captured in full"
    }

    private var fallbackSubtitle: String? {
        if let winLine = input.winLine, !winLine.isEmpty {
            return winLine
        }
        return visibleHighlights.isEmpty ? "LifeFlow" : nil
    }

    private var fallbackSymbol: String {
        if input.runLine.lowercased().contains("run") {
            return "figure.run"
        }
        return "dumbbell.fill"
    }

    var body: some View {
        ZStack {
            backgroundLayer
            
            // The "Verified" Stamp
            VStack {
                HStack {
                    Spacer()
                    Image("stamp_verified_glass")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .opacity(0.8)
                        .blendMode(.screen)
                }
                Spacer()
            }
            .padding(30) // Assuming padding from snippet, adjusted if needed relative to safe area

            VStack(spacing: isStory ? 20 : 14) {
                header

                routeCard

                if !visibleHighlights.isEmpty {
                    highlightsPanel
                }

                if let winLine = input.winLine, !winLine.isEmpty {
                    winsRibbon(text: winLine)
                }

                footer
            }
            .padding(.horizontal, isStory ? 54 : 42)
            .padding(.top, isStory ? 84 : 54)
            .padding(.bottom, isStory ? 72 : 44)
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            Color.black

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
                    SIMD2<Float>(0.0, 0.5), SIMD2<Float>(0.5, 0.48), SIMD2<Float>(1.0, 0.52),
                    SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0)
                ],
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.10),
                    Color(red: 0.04, green: 0.11, blue: 0.22),
                    Color(red: 0.03, green: 0.08, blue: 0.18),
                    Color(red: 0.09, green: 0.05, blue: 0.20),
                    Color(red: 0.02, green: 0.16, blue: 0.25),
                    Color(red: 0.12, green: 0.07, blue: 0.20),
                    Color(red: 0.02, green: 0.07, blue: 0.12),
                    Color(red: 0.05, green: 0.09, blue: 0.23),
                    Color(red: 0.02, green: 0.04, blue: 0.09)
                ]
            )
            .opacity(0.9)
            .blur(radius: 24)

            RadialGradient(
                colors: [Color.cyan.opacity(0.22), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 360
            )
            .blendMode(.screen)
            
            // Film Grain Texture
            Image("texture_noise_grain")
                .resizable()
                .blendMode(.overlay)
                .opacity(0.2)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FLOW PRINT")
                .font(.system(size: isStory ? 26 : 20, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.82))

            Text(primaryTitleLine)
                .font(.system(size: isStory ? 58 : 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(secondaryTitleLine)
                .font(.system(size: isStory ? 25 : 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            if let weather = input.weatherLine, !weather.isEmpty {
                Text(weather)
                    .font(.system(size: isStory ? 20 : 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }

            if let pace = input.paceLine, !pace.isEmpty {
                Text(pace)
                    .font(.system(size: isStory ? 18 : 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routeCard: some View {
        FlowPrintRouteView(
            segments: input.routeSegments,
            fallbackTitle: fallbackTitle,
            fallbackSubtitle: fallbackSubtitle,
            fallbackSymbol: fallbackSymbol
        )
        .frame(maxWidth: .infinity)
        .frame(height: isStory ? 760 : 350)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 38))
        .overlay(
            RoundedRectangle(cornerRadius: 38)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        )
    }

    private var highlightsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WINS")
                .font(.system(size: isStory ? 17 : 13, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.75))

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(visibleHighlights) { highlight in
                    FlowPrintHighlightTile(highlight: highlight, isStory: isStory)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func winsRibbon(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: isStory ? 16 : 13, weight: .semibold))
                .foregroundStyle(.cyan)

            Text(text)
                .font(.system(size: isStory ? 18 : 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cyan.opacity(0.16), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack {
            Text(input.completionDate.formatted(date: .abbreviated, time: .omitted).uppercased())
                .font(.system(size: isStory ? 19 : 14, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.72))

            Spacer()

            Text("LifeFlow")
                .font(.system(size: isStory ? 24 : 17, weight: .bold, design: .serif))
                .foregroundStyle(.white.opacity(0.88))
        }
    }
}

private struct FlowPrintHighlightTile: View {
    let highlight: FlowPrintHighlight
    let isStory: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: highlight.icon)
                .font(.system(size: isStory ? 16 : 13, weight: .semibold))
                .foregroundStyle(highlight.tone.color)
                .frame(width: isStory ? 30 : 24, height: isStory ? 30 : 24)
                .background(highlight.tone.color.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(highlight.value)
                    .font(.system(size: isStory ? 22 : 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(highlight.label.uppercased())
                    .font(.system(size: isStory ? 10 : 8, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(highlight.tone.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(highlight.tone.color.opacity(0.34), lineWidth: 1)
        )
    }
}

private struct FlowPrintRouteView: View {
    let segments: [FlowPrintRouteSegment]
    let fallbackTitle: String
    let fallbackSubtitle: String?
    let fallbackSymbol: String

    private var isRunFallback: Bool {
        fallbackSymbol == "figure.run"
    }

    private struct SegmentPath: Identifiable {
        let id = UUID()
        let points: [CGPoint]
        let isAhead: Bool
    }

    var body: some View {
        GeometryReader { geo in
            let rendered = normalizedSegments(for: geo.size)

            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.black.opacity(0.34))

                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)

                if rendered.isEmpty {
                    routeFallback
                } else {
                    ForEach(rendered) { segment in
                        let baseColor = segment.isAhead ? Color.green : Color.orange

                        path(for: segment.points)
                            .stroke(baseColor.opacity(0.18), style: StrokeStyle(lineWidth: 24, lineCap: .round, lineJoin: .round))
                            .blur(radius: 14)

                        path(for: segment.points)
                            .stroke(baseColor.opacity(0.3), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                            .blur(radius: 7)

                        path(for: segment.points)
                            .stroke(baseColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .padding(18)
        }
    }

    private var routeFallback: some View {
        VStack(spacing: 18) {
            if isRunFallback {
                treadmillWaveFallback
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 122, height: 122)

                    Circle()
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 2)
                        .frame(width: 86, height: 86)

                    Image(systemName: fallbackSymbol)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
            }

            Text(fallbackTitle)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 30)

            if let fallbackSubtitle, !fallbackSubtitle.isEmpty {
                Text(fallbackSubtitle)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 36)
            }
        }
    }

    private var treadmillWaveFallback: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<24, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.88),
                                Color.blue.opacity(0.78),
                                Color.purple.opacity(0.82)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 8, height: waveHeight(at: index))
                    .shadow(color: Color.purple.opacity(0.26), radius: 6, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func waveHeight(at index: Int) -> CGFloat {
        let normalized = Double(index) / 5.3
        let amplitude = (sin(normalized) + cos(normalized * 0.62)) * 0.5 + 0.5
        return CGFloat(48 + amplitude * 108)
    }

    private func path(for points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func normalizedSegments(for size: CGSize) -> [SegmentPath] {
        let allCoordinates = segments.flatMap(\.coordinates)
        guard allCoordinates.count > 1 else { return [] }

        let minLat = allCoordinates.map(\.latitude).min() ?? 0
        let maxLat = allCoordinates.map(\.latitude).max() ?? 0
        let minLon = allCoordinates.map(\.longitude).min() ?? 0
        let maxLon = allCoordinates.map(\.longitude).max() ?? 0

        let latRange = max(0.000001, maxLat - minLat)
        let lonRange = max(0.000001, maxLon - minLon)

        let horizontalPadding: CGFloat = 40
        let verticalPadding: CGFloat = 40
        let drawableWidth = max(1, size.width - horizontalPadding * 2)
        let drawableHeight = max(1, size.height - verticalPadding * 2)

        let scale = min(drawableWidth / lonRange, drawableHeight / latRange)
        let contentWidth = lonRange * scale
        let contentHeight = latRange * scale
        let offsetX = (size.width - contentWidth) / 2
        let offsetY = (size.height - contentHeight) / 2

        return segments.compactMap { segment in
            guard segment.coordinates.count > 1 else { return nil }

            let points = segment.coordinates.map { coordinate -> CGPoint in
                let x = ((coordinate.longitude - minLon) * scale) + offsetX
                let y = ((maxLat - coordinate.latitude) * scale) + offsetY
                return CGPoint(x: x, y: y)
            }
            return SegmentPath(points: points, isAhead: segment.isAhead)
        }
    }
}
