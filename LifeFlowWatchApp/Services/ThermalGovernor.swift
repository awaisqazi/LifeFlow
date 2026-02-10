import Foundation
import Observation

@MainActor
@Observable
final class ThermalGovernor {
    enum Mode: String {
        case nominal
        case fair
        case serious
        case critical

        var sensorSampleRateHz: Double {
            switch self {
            case .nominal:
                return 50
            case .fair:
                return 40
            case .serious:
                return 25
            case .critical:
                return 15
            }
        }

        var allowsVoicePrompts: Bool {
            self == .nominal || self == .fair
        }

        var allowsFluidAnimations: Bool {
            self == .nominal
        }
    }

    private(set) var mode: Mode = .nominal

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        update(for: ProcessInfo.processInfo.thermalState)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc
    private func handleThermalStateDidChange() {
        update(for: ProcessInfo.processInfo.thermalState)
    }

    private func update(for state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal:
            mode = .nominal
        case .fair:
            mode = .fair
        case .serious:
            mode = .serious
        case .critical:
            mode = .critical
        @unknown default:
            mode = .fair
        }
    }
}
