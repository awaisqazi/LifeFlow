//
//  RunWeatherService.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import CoreLocation
import Foundation
import WeatherKit
import Observation

@Observable
final class RunWeatherService: NSObject, CLLocationManagerDelegate {
    static let fallbackSummary = "Conditions unavailable. Trust your rhythm and start smooth."
    static let loadingSummary = "Checking live WeatherKit conditions..."
    static let loadingCompactSummary = "Checking weather..."
    static let fallbackCompactSummary = "Weather unavailable"
    static let locationDeniedSummary = "Location is off. Enable it to fetch live WeatherKit conditions."
    static let locationDeniedCompactSummary = "Location required"

    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService()

    private(set) var summaryText: String = RunWeatherService.loadingSummary
    private(set) var compactSummaryText: String = RunWeatherService.loadingCompactSummary
    private(set) var isLoading: Bool = false
    private(set) var usesFallback: Bool = true
    private(set) var lastUpdatedAt: Date?

    private var lastFetchAttemptAt: Date?
    private let refreshInterval: TimeInterval = 60 * 15
    private let fallbackRetryInterval: TimeInterval = 90

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func fetchIfNeeded(force: Bool = false) {
        if isLoading { return }
        if !force,
           let lastFetchAttemptAt {
            let interval = usesFallback ? fallbackRetryInterval : refreshInterval
            if Date().timeIntervalSince(lastFetchAttemptAt) < interval {
                return
            }
        }

        isLoading = true
        lastFetchAttemptAt = Date()
        summaryText = Self.loadingSummary
        compactSummaryText = Self.loadingCompactSummary

        let status = locationManager.authorizationStatus
        print("🌤️ WeatherKit fetch - Location status: \(status.rawValue)")

        switch status {
        case .notDetermined:
            print("   Requesting location authorization...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("   Location authorized, requesting location...")
            locationManager.requestLocation()
        case .restricted, .denied:
            print("   Location access denied or restricted")
            applyFallback(
                summary: Self.locationDeniedSummary,
                compactSummary: Self.locationDeniedCompactSummary
            )
        @unknown default:
            print("   Unknown authorization status")
            applyFallback(
                summary: Self.fallbackSummary,
                compactSummary: Self.fallbackCompactSummary
            )
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if isLoading {
                manager.requestLocation()
            }
        case .denied, .restricted:
            applyFallback(
                summary: Self.locationDeniedSummary,
                compactSummary: Self.locationDeniedCompactSummary
            )
        case .notDetermined:
            break
        @unknown default:
            applyFallback(
                summary: Self.fallbackSummary,
                compactSummary: Self.fallbackCompactSummary
            )
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            print("⚠️ WeatherKit: No location available")
            applyFallback(
                summary: Self.fallbackSummary,
                compactSummary: Self.fallbackCompactSummary
            )
            return
        }

        print("✓ WeatherKit: Got location, fetching weather...")
        Task { [weak self] in
            guard let self else { return }
            do {
                let weather = try await weatherService.weather(for: location)
                let fahrenheit = weather.currentWeather.temperature.converted(to: .fahrenheit).value
                let condition = humanReadableCondition(String(describing: weather.currentWeather.condition))
                let coachLine = coachMessage(for: fahrenheit)
                let summary = "\(Int(fahrenheit.rounded()))\u{00B0}F and \(condition). \(coachLine)"
                let compactSummary = "\(Int(fahrenheit.rounded()))\u{00B0}F • \(condition.capitalized)"

                print("✓ WeatherKit: Success - \(compactSummary)")
                
                DispatchQueue.main.async {
                    self.summaryText = summary
                    self.compactSummaryText = compactSummary
                    self.isLoading = false
                    self.usesFallback = false
                    self.lastUpdatedAt = Date()
                }
            } catch {
                print("⚠️ WeatherKit fetch error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   Domain: \(nsError.domain), Code: \(nsError.code)")
                    if nsError.domain == "WeatherDaemonError" && nsError.code == 1 {
                        print("   ⚠️ HINT: WeatherKit may not be enabled in your App ID on developer.apple.com")
                        print("   ⚠️ Visit Certificates, Identifiers & Profiles, enable WeatherKit, and wait 30 min")
                    }
                }
                DispatchQueue.main.async {
                    self.applyFallback(
                        summary: Self.fallbackSummary,
                        compactSummary: Self.fallbackCompactSummary
                    )
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ WeatherKit location error: \(error.localizedDescription)")
        applyFallback(
            summary: Self.fallbackSummary,
            compactSummary: Self.fallbackCompactSummary
        )
    }

    var persistedSummary: String? {
        guard !usesFallback else { return nil }
        return summaryText
    }

    private func applyFallback(summary: String, compactSummary: String) {
        summaryText = summary
        compactSummaryText = compactSummary
        isLoading = false
        usesFallback = true
    }

    private func humanReadableCondition(_ raw: String) -> String {
        let words = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(
                of: "([a-z])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
        return words.lowercased()
    }

    private func coachMessage(for fahrenheit: Double) -> String {
        switch fahrenheit {
        case ..<40:
            return "Layer up and start easy."
        case 40..<70:
            return "Perfect PR weather."
        case 70..<82:
            return "Great day to build momentum."
        default:
            return "Hydrate early and pace with control."
        }
    }
}
