import Foundation

enum WatchFormatting {
    static func pace(_ secondsPerMile: Double?) -> String {
        guard let secondsPerMile, secondsPerMile.isFinite, secondsPerMile > 0 else {
            return "--:--"
        }

        let totalSeconds = Int(secondsPerMile.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
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
        String(format: "%.2f mi", max(0, miles))
    }

    static func heartRate(_ bpm: Double?) -> String {
        guard let bpm, bpm > 0 else { return "--" }
        return String(format: "%.0f", bpm)
    }

    static func cadence(_ spm: Double?) -> String {
        guard let spm, spm > 0 else { return "--" }
        return String(format: "%.0f", spm)
    }

    static func fuel(_ grams: Double) -> String {
        String(format: "%.0f g", max(0, grams))
    }
}
