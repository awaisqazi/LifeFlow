//
//  LiquidGlassDesignSystem.swift
//  LifeFlow
//
//  Single source of truth for the Liquid Glass design language.
//  Three layers: MeshGradient base → ultraThinMaterial refraction → specular stroke.
//

import SwiftUI

// MARK: - Design Tokens

/// Central namespace for all Liquid Glass design tokens.
enum LiquidGlass {

    // MARK: Corner Radii
    /// Compact elements: pills, chips, small controls.
    static let cornerRadiusSmall: CGFloat = 16
    /// Default card radius.
    static let cornerRadius: CGFloat = 24
    /// Hero / panorama / large feature cards.
    static let cornerRadiusLarge: CGFloat = 32

    // MARK: Specular Stroke
    /// Width of the highlight edge stroke.
    static let strokeWidth: CGFloat = 1.5
    /// The gradient that mimics ambient light catching a glass edge.
    static let specularGradient = LinearGradient(
        colors: [.white.opacity(0.5), .clear, .white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Shadow
    static let shadowRadius: CGFloat = 20
    static let shadowY: CGFloat = 15
    static let shadowColor = Color.black.opacity(0.25)
}

// MARK: - Liquid Glass Card Modifier

/// The universal card treatment: frosted material + forced dark scheme + specular stroke.
struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        // MARK: GPU Optimization — Isolate background from foreground.
        // .compositingGroup() only wraps the material/gradient background layer,
        // NOT the foreground content. Text rendered inside a compositing group
        // loses subpixel antialiasing, appearing blurry or "heavy." By keeping
        // content outside the composited background, text stays crisp.
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .compositingGroup()
            }
            .environment(\.colorScheme, .dark)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LiquidGlass.specularGradient,
                        lineWidth: LiquidGlass.strokeWidth
                    )
                    .blendMode(.overlay)
            )
            .shadow(
                color: LiquidGlass.shadowColor,
                radius: LiquidGlass.shadowRadius,
                x: 0,
                y: LiquidGlass.shadowY
            )
    }
}

/// The chip / pill treatment: same recipe, smaller radius, lighter shadow.
struct LiquidGlassChipModifier: ViewModifier {
    var cornerRadius: CGFloat = LiquidGlass.cornerRadiusSmall

    func body(content: Content) -> some View {
        // Same isolation pattern: compositingGroup wraps only the background.
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .compositingGroup()
            }
            .environment(\.colorScheme, .dark)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LiquidGlass.specularGradient,
                        lineWidth: 1
                    )
                    .blendMode(.overlay)
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Standard Liquid Glass card treatment.
    /// - Parameter cornerRadius: Defaults to `LiquidGlass.cornerRadius` (24).
    func liquidGlassCard(cornerRadius: CGFloat = LiquidGlass.cornerRadius) -> some View {
        modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius))
    }

    /// Compact chip / pill treatment — no drop shadow.
    func liquidGlassChip(cornerRadius: CGFloat = LiquidGlass.cornerRadiusSmall) -> some View {
        modifier(LiquidGlassChipModifier(cornerRadius: cornerRadius))
    }
}
