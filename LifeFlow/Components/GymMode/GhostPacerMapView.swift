//
//  GhostPacerMapView.swift
//  LifeFlow
//
//  A MapKit view that overlays a "ghost pacer" on the current route,
//  showing where the runner was during their personal best (PB) at
//  the same elapsed workout time. Uses linear interpolation for
//  smooth ghost marker animation.
//

import SwiftUI
import MapKit

// MARK: - GhostPacerMapView

/// Displays the runner's current route and a ghost pacer from their PB.
///
/// Architecture notes:
/// - `currentRoute` should be pre-simplified via `PolylineDownsampler` to
///   avoid per-frame SwiftUI diffing with 1Hz raw CLLocation updates.
/// - The ghost marker uses linear interpolation between PB timestamps
///   for smooth, buttery animation without requiring extrapolation.
/// - Camera follows the user's heading for an immersive first-person feel.
struct GhostPacerMapView: View {
    /// The runner's current route (downsampled coordinates).
    var currentRoute: [CLLocationCoordinate2D]

    /// The personal best route to overlay as a dashed ghost line.
    var pbRoute: [CLLocationCoordinate2D]

    /// Timestamps (in seconds from workout start) for each PB route point.
    /// Must be the same count as `pbRoute`.
    var pbTimestamps: [TimeInterval]

    /// Elapsed time since workout start, used to interpolate the ghost position.
    var elapsedWorkoutTime: TimeInterval

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        Map(position: $cameraPosition) {
            // MARK: PB Route — Dashed Liquid Glass polyline
            // Semi-transparent dashed line shows where the runner *was*
            // during their personal best at this same elapsed time.
            MapPolyline(coordinates: pbRoute)
                .stroke(
                    .white.opacity(0.4),
                    style: StrokeStyle(lineWidth: 6, dash: [8, 8])
                )

            // MARK: Current Route — Gradient polyline
            // Solid cyan→blue gradient showing the runner's live trajectory.
            MapPolyline(coordinates: currentRoute)
                .stroke(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 8
                )

            // MARK: Ghost Pacer Marker
            // Interpolated annotation that slides along the PB route,
            // showing exactly where the ghost runner is right now.
            if let ghostLocation = calculateGhostLocation() {
                Annotation("Ghost", coordinate: ghostLocation) {
                    Circle()
                        .fill(.white.shadow(.inner(color: .cyan, radius: 4)))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(.cyan.opacity(0.6), lineWidth: 2)
                                .frame(width: 20, height: 20)
                        )
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }

    // MARK: - Ghost Location Interpolation

    /// Calculates the ghost pacer's current position by linearly
    /// interpolating between PB route waypoints based on elapsed time.
    ///
    /// If the runner is ahead of their PB, the ghost sits at the last
    /// PB point. If behind, it sits at the appropriate interpolated position.
    private func calculateGhostLocation() -> CLLocationCoordinate2D? {
        guard !pbRoute.isEmpty, !pbTimestamps.isEmpty,
              pbRoute.count == pbTimestamps.count else {
            return nil
        }

        // If we've passed the entire PB, ghost stays at the finish.
        guard let index = pbTimestamps.firstIndex(where: { $0 >= elapsedWorkoutTime }),
              index > 0 else {
            return pbRoute.last
        }

        // MARK: Linear interpolation for smooth animation
        // Instead of jumping between waypoints, we interpolate the ghost
        // position between the two bracketing timestamps for buttery
        // smooth movement even at low GPS sample rates.
        let prevTimestamp = pbTimestamps[index - 1]
        let nextTimestamp = pbTimestamps[index]
        let interval = nextTimestamp - prevTimestamp

        guard interval > 0 else { return pbRoute[index] }

        let fraction = (elapsedWorkoutTime - prevTimestamp) / interval

        return interpolate(
            from: pbRoute[index - 1],
            to: pbRoute[index],
            fraction: min(1.0, max(0.0, fraction))
        )
    }

    /// Linear interpolation between two coordinates.
    /// For short distances (< 1km between points), great-circle math
    /// isn't necessary; simple linear interpolation suffices.
    private func interpolate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        fraction: Double
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: from.latitude + (to.latitude - from.latitude) * fraction,
            longitude: from.longitude + (to.longitude - from.longitude) * fraction
        )
    }
}

// MARK: - Preview

#Preview("Ghost Pacer Demo") {
    // Simulated route along a straight line
    let route = (0..<20).map { i in
        CLLocationCoordinate2D(
            latitude: 37.7749 + Double(i) * 0.001,
            longitude: -122.4194 + Double(i) * 0.0005
        )
    }
    let timestamps = (0..<20).map { TimeInterval($0) * 30 } // 30s per point

    GhostPacerMapView(
        currentRoute: Array(route.prefix(10)),
        pbRoute: route,
        pbTimestamps: timestamps,
        elapsedWorkoutTime: 150 // 2.5 minutes in
    )
}
