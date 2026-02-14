//
//  SavingsJarCard.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

/// A visualization card showing a jar filling with liquid gold/green fluid.
/// Reuses the water animation logic with modified colors for savings goals.
struct SavingsJarCard: View {
    let goal: Goal
    @State private var wavePhase: Double = 0
    @State private var shimmerPhase: Double = 0
    
    private var fillLevel: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(goal.currentAmount / goal.targetAmount, 1.0)
    }
    
    private var plan: DailyPlan {
        goal.dailyPlan
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "banknote.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                StatusBadge(status: plan.status)
            }
            
            // Jar visualization
            HStack(spacing: 20) {
                // The Savings Jar
                SavingsJarView(fillLevel: fillLevel, wavePhase: wavePhase, shimmerPhase: shimmerPhase)
                    .frame(width: 100, height: 140)
                
                // Stats
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("$\(goal.currentAmount, specifier: "%.0f")")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("$\(goal.targetAmount, specifier: "%.0f")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Goal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("$\(plan.amountNeededToday, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundStyle(plan.isUnrealistic ? .red : .green)
                    }
                    
                    if let warning = plan.warningMessage {
                        Text(warning)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            
            // Progress bar
            ProgressView(value: fillLevel)
                .tint(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Days remaining
            if plan.daysRemaining > 0 {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("\(plan.daysRemaining) days remaining")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .liquidGlassCard(cornerRadius: 20)
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 2
        }
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            shimmerPhase = 1
        }
    }
}

// MARK: - Savings Jar View

/// The jar shape filled with animated gold liquid
struct SavingsJarView: View {
    let fillLevel: Double
    let wavePhase: Double
    let shimmerPhase: Double
    
    // Gold gradient for the liquid
    private var goldGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.7, green: 0.5, blue: 0.1),   // Dark gold bottom
                Color(red: 0.85, green: 0.65, blue: 0.13), // Golden
                Color(red: 1.0, green: 0.84, blue: 0.0),   // Bright gold
                Color(red: 1.0, green: 0.9, blue: 0.4),    // Light gold highlight
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
    
    // Shimmer stops
    private var shimmerStops: [Gradient.Stop] {
        let center = max(0.1, min(0.9, shimmerPhase))
        return [
            .init(color: .clear, location: 0),
            .init(color: .white.opacity(0.3), location: max(0, center - 0.15)),
            .init(color: .white.opacity(0.5), location: center),
            .init(color: .white.opacity(0.3), location: min(1, center + 0.15)),
            .init(color: .clear, location: 1),
        ]
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Jar outline (glass effect)
                JarShape()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                
                // Jar glass background
                JarShape()
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                
                // Liquid gold fill
                JarLiquidShape(fillLevel: fillLevel, wavePhase: wavePhase)
                    .fill(goldGradient)
                    .clipShape(JarShape())
                
                // Shimmer overlay
                JarLiquidShape(fillLevel: fillLevel, wavePhase: wavePhase)
                    .fill(
                        LinearGradient(
                            stops: shimmerStops,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(JarShape())
                
                // Coin stack decoration at bottom
                if fillLevel > 0.1 {
                    CoinStackView()
                        .frame(width: geo.size.width * 0.4, height: geo.size.height * 0.15)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.85)
                }
                
                // Fill percentage
                Text("\(Int(fillLevel * 100))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.5)
            }
        }
    }
}

// MARK: - Jar Shape

/// A jar/vessel shape for savings visualization
struct JarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Jar neck
        let neckWidth = width * 0.5
        let neckHeight = height * 0.12
        let neckInset = (width - neckWidth) / 2
        
        // Body
        let bodyTop = neckHeight
        let bodyWidth = width * 0.9
        let bodyInset = (width - bodyWidth) / 2
        
        // Start at top left of neck
        path.move(to: CGPoint(x: neckInset, y: 0))
        
        // Top of neck
        path.addLine(to: CGPoint(x: width - neckInset, y: 0))
        
        // Right side of neck down
        path.addLine(to: CGPoint(x: width - neckInset, y: neckHeight * 0.5))
        
        // Curve out to body
        path.addCurve(
            to: CGPoint(x: width - bodyInset, y: bodyTop + height * 0.1),
            control1: CGPoint(x: width - neckInset + 10, y: neckHeight * 0.7),
            control2: CGPoint(x: width - bodyInset, y: bodyTop)
        )
        
        // Right side of body
        path.addLine(to: CGPoint(x: width - bodyInset, y: height * 0.85))
        
        // Bottom right curve
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: width - bodyInset, y: height * 0.95),
            control2: CGPoint(x: width * 0.7, y: height)
        )
        
        // Bottom left curve
        path.addCurve(
            to: CGPoint(x: bodyInset, y: height * 0.85),
            control1: CGPoint(x: width * 0.3, y: height),
            control2: CGPoint(x: bodyInset, y: height * 0.95)
        )
        
        // Left side of body
        path.addLine(to: CGPoint(x: bodyInset, y: bodyTop + height * 0.1))
        
        // Curve in to neck
        path.addCurve(
            to: CGPoint(x: neckInset, y: neckHeight * 0.5),
            control1: CGPoint(x: bodyInset, y: bodyTop),
            control2: CGPoint(x: neckInset - 10, y: neckHeight * 0.7)
        )
        
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Jar Liquid Shape

/// Liquid inside the jar with wavy surface
struct JarLiquidShape: Shape {
    var fillLevel: Double
    var wavePhase: Double
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(fillLevel, wavePhase) }
        set {
            fillLevel = newValue.first
            wavePhase = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard fillLevel > 0 else { return path }
        
        let width = rect.width
        let height = rect.height
        
        // Calculate liquid surface
        let bodyTop = height * 0.12
        let fillableHeight = height - bodyTop
        let liquidHeight = fillableHeight * min(fillLevel, 0.95)
        let liquidTop = height - liquidHeight
        
        // Body dimensions
        let bodyWidth = width * 0.9
        let bodyInset = (width - bodyWidth) / 2
        
        // Start at bottom center
        path.move(to: CGPoint(x: width * 0.5, y: height))
        
        // Bottom left curve
        path.addCurve(
            to: CGPoint(x: bodyInset, y: height * 0.85),
            control1: CGPoint(x: width * 0.3, y: height),
            control2: CGPoint(x: bodyInset, y: height * 0.95)
        )
        
        // Left side up to liquid level
        path.addLine(to: CGPoint(x: bodyInset, y: liquidTop))
        
        // Wavy surface
        let steps = 30
        let stepWidth = (width - 2 * bodyInset) / CGFloat(steps)
        let waveAmp: CGFloat = 4
        
        for i in 0...steps {
            let x = bodyInset + stepWidth * CGFloat(i)
            let normalizedX = CGFloat(i) / CGFloat(steps)
            
            let wave = sin(normalizedX * .pi * 3 + wavePhase) * waveAmp
            let y = liquidTop + wave
            
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Right side down
        path.addLine(to: CGPoint(x: width - bodyInset, y: height * 0.85))
        
        // Bottom right curve
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height),
            control1: CGPoint(x: width - bodyInset, y: height * 0.95),
            control2: CGPoint(x: width * 0.7, y: height)
        )
        
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Coin Stack

/// Decorative coin stack at bottom of jar
struct CoinStackView: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.85, blue: 0.0),
                                Color(red: 0.8, green: 0.6, blue: 0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 10
                        )
                    )
                    .frame(width: 14, height: 14)
                    .offset(x: CGFloat(i - 1) * 8, y: CGFloat(i) * -2)
            }
        }
    }
}

// MARK: - Status Badge

/// Small badge showing goal status
struct StatusBadge: View {
    let status: GoalStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.title)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundStyle(statusColor)
        .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .onTrack: return .blue
        case .behind: return .orange
        case .ahead: return .green
        case .completed: return .purple
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        SavingsJarCard(goal: Goal(
            title: "Vacation Fund",
            targetAmount: 2000,
            currentAmount: 1200,
            deadline: Date().addingTimeInterval(86400 * 30),
            type: .savings
        ))
        .padding()
    }
    .preferredColorScheme(.dark)
}
