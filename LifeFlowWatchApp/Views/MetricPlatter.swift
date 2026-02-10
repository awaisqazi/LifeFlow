import SwiftUI

struct MetricPlatter: View {
    let title: String
    let value: String
    var accent: Color = .mint

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .glassEffect(.regular.tint(accent.opacity(0.22)), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
}
