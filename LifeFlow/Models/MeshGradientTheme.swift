//
//  MeshGradientTheme.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

/// Defines color palettes for the animated mesh gradient background.
/// Each theme is based on psychological color theory to induce specific mental states.
enum MeshGradientTheme: CaseIterable {
    /// Morning/Focus state - Cool blues and teals to induce concentration
    case flow
    
    /// Evening/Reflection state - Warm oranges and deep purples for contemplation
    case temple
    
    /// Aspiration state - Cosmic violets and deep blues for forward-thinking
    case horizon
    
    /// Success state - Gold and green for achievement celebration
    case success
    
    /// Returns the 9-color palette (3x3 grid) for this theme
    var colors: [Color] {
        switch self {
        case .flow:
            return flowColors
        case .temple:
            return templeColors
        case .horizon:
            return horizonColors
        case .success:
            return successColors
        }
    }
    
    // MARK: - Flow Theme (Blues & Teals)
    // Psychological effect: Focus, clarity, calm productivity
    
    private var flowColors: [Color] {
        [
            // Row 0 - Top edge
            Color(red: 0.02, green: 0.08, blue: 0.18),   // Deep ocean
            Color(red: 0.05, green: 0.15, blue: 0.28),   // Midnight teal
            Color(red: 0.03, green: 0.10, blue: 0.22),   // Navy depth
            
            // Row 1 - Middle (most visible, richer colors)
            Color(red: 0.08, green: 0.22, blue: 0.38),   // Electric teal
            Color(red: 0.12, green: 0.32, blue: 0.48),   // Bright cyan core
            Color(red: 0.06, green: 0.18, blue: 0.32),   // Ocean blue
            
            // Row 2 - Bottom edge
            Color(red: 0.04, green: 0.12, blue: 0.24),   // Deep slate
            Color(red: 0.08, green: 0.20, blue: 0.35),   // Steel blue
            Color(red: 0.05, green: 0.14, blue: 0.26),   // Twilight blue
        ]
    }
    
    // MARK: - Temple Theme (Oranges & Purples)
    // Psychological effect: Reflection, introspection, evening calm
    
    private var templeColors: [Color] {
        [
            // Row 0 - Top edge (sunset sky)
            Color(red: 0.18, green: 0.08, blue: 0.22),   // Deep violet
            Color(red: 0.28, green: 0.12, blue: 0.18),   // Dusk rose
            Color(red: 0.22, green: 0.10, blue: 0.25),   // Purple night
            
            // Row 1 - Middle (warm core)
            Color(red: 0.35, green: 0.15, blue: 0.12),   // Warm amber
            Color(red: 0.42, green: 0.22, blue: 0.15),   // Sunset orange
            Color(red: 0.30, green: 0.12, blue: 0.20),   // Crimson dusk
            
            // Row 2 - Bottom edge
            Color(red: 0.15, green: 0.06, blue: 0.18),   // Deep plum
            Color(red: 0.25, green: 0.10, blue: 0.15),   // Burgundy
            Color(red: 0.18, green: 0.08, blue: 0.20),   // Violet shadow
        ]
    }
    
    // MARK: - Horizon Theme (Cosmic Violets)
    // Psychological effect: Aspiration, possibility, future-focus
    
    private var horizonColors: [Color] {
        [
            // Row 0 - Top edge (cosmos)
            Color(red: 0.08, green: 0.05, blue: 0.18),   // Deep space
            Color(red: 0.12, green: 0.08, blue: 0.28),   // Nebula purple
            Color(red: 0.10, green: 0.06, blue: 0.22),   // Cosmic void
            
            // Row 1 - Middle (stardust)
            Color(red: 0.18, green: 0.12, blue: 0.38),   // Bright violet
            Color(red: 0.22, green: 0.15, blue: 0.45),   // Electric purple
            Color(red: 0.15, green: 0.10, blue: 0.35),   // Amethyst
            
            // Row 2 - Bottom edge
            Color(red: 0.06, green: 0.04, blue: 0.15),   // Midnight
            Color(red: 0.10, green: 0.08, blue: 0.25),   // Deep indigo
            Color(red: 0.08, green: 0.05, blue: 0.18),   // Space blue
        ]
    }
    
    // MARK: - Success Theme (Gold & Green)
    // Psychological effect: Achievement, reward, celebration
    
    private var successColors: [Color] {
        [
            // Row 0 - Top edge
            Color(red: 0.15, green: 0.20, blue: 0.08),   // Forest edge
            Color(red: 0.25, green: 0.30, blue: 0.10),   // Bright leaf
            Color(red: 0.18, green: 0.22, blue: 0.08),   // Moss green
            
            // Row 1 - Middle (golden glow)
            Color(red: 0.40, green: 0.35, blue: 0.12),   // Rich gold
            Color(red: 0.55, green: 0.48, blue: 0.15),   // Radiant gold
            Color(red: 0.35, green: 0.32, blue: 0.10),   // Warm gold
            
            // Row 2 - Bottom edge
            Color(red: 0.12, green: 0.18, blue: 0.06),   // Deep green
            Color(red: 0.20, green: 0.28, blue: 0.08),   // Emerald
            Color(red: 0.15, green: 0.20, blue: 0.06),   // Forest floor
        ]
    }
}

// MARK: - Theme Selection from Tab

extension MeshGradientTheme {
    /// Returns the appropriate theme for a given tab
    static func forTab(_ tab: LifeFlowTab) -> MeshGradientTheme {
        switch tab {
        case .flow:
            return .flow
        case .temple:
            return .temple
        case .horizon:
            return .horizon
        }
    }
}

// MARK: - Color Interpolation

extension MeshGradientTheme {
    /// Interpolates between two themes for smooth transitions
    static func interpolate(from: MeshGradientTheme, to: MeshGradientTheme, progress: Double) -> [Color] {
        let fromColors = from.colors
        let toColors = to.colors
        
        return zip(fromColors, toColors).map { fromColor, toColor in
            interpolateColor(from: fromColor, to: toColor, progress: progress)
        }
    }
    
    /// Blends a theme with success overlay for achievement pulses
    static func withSuccessPulse(base: MeshGradientTheme, intensity: Double) -> [Color] {
        let baseColors = base.colors
        let successColors = MeshGradientTheme.success.colors
        
        return zip(baseColors, successColors).map { baseColor, successColor in
            interpolateColor(from: baseColor, to: successColor, progress: intensity)
        }
    }
    
    private static func interpolateColor(from: Color, to: Color, progress: Double) -> Color {
        let fromComponents = from.cgColor?.components ?? [0, 0, 0, 1]
        let toComponents = to.cgColor?.components ?? [0, 0, 0, 1]
        
        let r = fromComponents[0] + (toComponents[0] - fromComponents[0]) * progress
        let g = fromComponents[1] + (toComponents[1] - fromComponents[1]) * progress
        let b = fromComponents[2] + (toComponents[2] - fromComponents[2]) * progress
        
        return Color(red: r, green: g, blue: b)
    }
}
