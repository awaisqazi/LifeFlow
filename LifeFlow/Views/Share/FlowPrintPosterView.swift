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
    
    var body: some View {
        ZStack {
            backgroundLayer
            
            VStack(spacing: isStory ? 26 : 18) {
                header
                
                routeCard
                
                footer
            }
            .padding(.horizontal, isStory ? 56 : 48)
            .padding(.top, isStory ? 108 : 76)
            .padding(.bottom, isStory ? 92 : 64)
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
                    Color(red: 0.03, green: 0.05, blue: 0.10),
                    Color(red: 0.05, green: 0.11, blue: 0.22),
                    Color(red: 0.02, green: 0.08, blue: 0.16),
                    Color(red: 0.08, green: 0.04, blue: 0.18),
                    Color(red: 0.03, green: 0.16, blue: 0.23),
                    Color(red: 0.12, green: 0.07, blue: 0.20),
                    Color(red: 0.02, green: 0.07, blue: 0.12),
                    Color(red: 0.05, green: 0.09, blue: 0.21),
                    Color(red: 0.02, green: 0.04, blue: 0.09)
                ]
            )
            .opacity(0.88)
            .blur(radius: 26)
            
            RadialGradient(
                colors: [Color.cyan.opacity(0.22), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 380
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FLOW PRINT")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.82))
            
            Text("\(input.runLine) • \(input.durationLine) • \(input.templeLine)")
                .font(.system(size: isStory ? 42 : 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            
            if let weather = input.weatherLine, !weather.isEmpty {
                Text(weather)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var routeCard: some View {
        VStack(spacing: 14) {
            FlowPrintRouteView(segments: input.routeSegments)
                .frame(maxWidth: .infinity)
                .frame(height: isStory ? 940 : 520)
                .background(Color.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 38))
                .overlay(
                    RoundedRectangle(cornerRadius: 38)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
            
            if let pace = input.paceLine, !pace.isEmpty {
                Text(pace)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 42))
        .overlay(
            RoundedRectangle(cornerRadius: 42)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private var footer: some View {
        HStack {
            Text(input.completionDate.formatted(date: .abbreviated, time: .omitted).uppercased())
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.7))
            
            Spacer()
            
            Text("LifeFlow")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(.white.opacity(0.88))
        }
    }
}

private struct FlowPrintRouteView: View {
    let segments: [FlowPrintRouteSegment]
    
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
                    .fill(Color.black.opacity(0.32))
                
                if rendered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Route unavailable")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                } else {
                    ForEach(rendered) { segment in
                        let baseColor = segment.isAhead ? Color.green : Color.orange
                        
                        path(for: segment.points)
                            .stroke(baseColor.opacity(0.18), style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))
                            .blur(radius: 14)
                        
                        path(for: segment.points)
                            .stroke(baseColor.opacity(0.32), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                            .blur(radius: 7)
                        
                        path(for: segment.points)
                            .stroke(baseColor, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .padding(20)
        }
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
        
        let horizontalPadding: CGFloat = 44
        let verticalPadding: CGFloat = 44
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

