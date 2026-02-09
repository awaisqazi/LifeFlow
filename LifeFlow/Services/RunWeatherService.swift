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

    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService()

    private(set) var summaryText: String = RunWeatherService.fallbackSummary
    private(set) var isLoading: Bool = false

    private var hasFetched = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func fetchIfNeeded(force: Bool = false) {
        if !force && hasFetched { return }

        isLoading = true
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .restricted, .denied:
            applyFallback()
        @unknown default:
            applyFallback()
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
            applyFallback()
        case .notDetermined:
            break
        @unknown default:
            applyFallback()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            applyFallback()
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let weather = try await weatherService.weather(for: location)
                let fahrenheit = weather.currentWeather.temperature.converted(to: .fahrenheit).value
                let condition = humanReadableCondition(String(describing: weather.currentWeather.condition))
                let coachLine = coachMessage(for: fahrenheit)
                let summary = "\(Int(fahrenheit.rounded()))\u{00B0}F and \(condition). \(coachLine)"

                DispatchQueue.main.async {
                    self.summaryText = summary
                    self.isLoading = false
                    self.hasFetched = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.applyFallback()
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        applyFallback()
    }

    private func applyFallback() {
        summaryText = Self.fallbackSummary
        isLoading = false
        hasFetched = true
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
