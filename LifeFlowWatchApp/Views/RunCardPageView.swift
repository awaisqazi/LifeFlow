import SwiftUI
import LifeFlowCore

/// Full-screen metric card for the Digital Crown run HUD.
/// Each card features a large hero value, a contextual accent ring or bar, and a subtle label.
struct RunCardPageView: View {
    let icon: String
    let label: String
    let heroValue: String
    let unit: String
    var accent: Color = .mint
    var subtitle: String? = nil
    var progress: Double? = nil

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 4)

            // Accent icon
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(accent.opacity(isLuminanceReduced ? 0.5 : 0.7))
                .padding(.bottom, 4)

            // Hero value
            Text(heroValue)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText(countsDown: false))
                .animation(.easeInOut(duration: 0.3), value: heroValue)

            // Unit label
            Text(unit)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 1)

            // Optional progress / zone bar
            if let progress {
                ZoneProgressBar(progress: progress, accent: accent)
                    .padding(.top, 10)
                    .padding(.horizontal, 24)
            }

            // Optional subtitle
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(accent.opacity(0.8))
                    .padding(.top, 6)
            }

            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(heroValue) \(unit)")
    }
}

/// A horizontal zone/progress bar with animated fill.
struct ZoneProgressBar: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accent.opacity(0.15))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.6), accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: 6)
    }
}
