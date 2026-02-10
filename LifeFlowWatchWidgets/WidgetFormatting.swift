import Foundation

enum WidgetFormatting {
    static func pace(_ secondsPerMile: Double?) -> String {
        guard let secondsPerMile, secondsPerMile > 0 else {
            return "--:--"
        }
        let total = Int(secondsPerMile.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%02d:%02d", minutes, remainder)
    }

    static func distance(_ miles: Double) -> String {
        String(format: "%.2f mi", miles)
    }

    static func heartRate(_ bpm: Double?) -> String {
        guard let bpm, bpm > 0 else { return "--" }
        return String(format: "%.0f", bpm)
    }

    static func fuel(_ grams: Double) -> String {
        String(format: "%.0f g", max(0, grams))
    }
}
