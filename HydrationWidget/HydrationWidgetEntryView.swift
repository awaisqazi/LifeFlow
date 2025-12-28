//
//  HydrationWidgetEntryView.swift
//  HydrationWidgetExtension
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import WidgetKit
import AppIntents

struct HydrationWidgetEntryView: View {
    var entry: Provider.Entry
    
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var widgetRenderingMode
    
    // Computation for water fill height (0.0 to 1.0)
    var waterFillHeight: CGFloat {
        guard entry.dailyGoal > 0 else { return 0 }
        return min(CGFloat(entry.waterIntake) / CGFloat(entry.dailyGoal), 1.0)
    }
    
    // Dynamic Colors based on Rendering Mode
    var isAccented: Bool {
        widgetRenderingMode == .accented
    }
    
    var gradientWater: some ShapeStyle {
        LinearGradient(
            colors: [Color.cyan, Color.blue],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    var buttonBackground8oz: Color {
        isAccented ? Color.primary.opacity(0.15) : Color.cyan.opacity(0.2)
    }
    
    var buttonForeground8oz: Color {
        isAccented ? Color.primary : Color.cyan
    }
    
    var buttonBackground16oz: Color {
        isAccented ? Color.primary.opacity(0.15) : Color.blue.opacity(0.2)
    }
    
    var buttonForeground16oz: Color {
        isAccented ? Color.primary : Color.blue
    }
    
    var buttonBackgroundMinus: Color {
        isAccented ? Color.primary.opacity(0.1) : Color.red.opacity(0.15)
    }
    
     var buttonForegroundMinus: Color {
        isAccented ? Color.primary.opacity(0.8) : Color.red.opacity(0.8)
    }
    
    // Text Colors
    var hydrationLabelColor: Color {
        isAccented ? Color.primary : Color.cyan
    }
    
    var dateTextColor: Color {
        isAccented ? Color.secondary : Color.white.opacity(0.5)
    }
    
    var secondaryTextColor: Color {
        isAccented ? Color.secondary : Color.white.opacity(0.6)
    }
    
    var dividerColor: Color {
        isAccented ? Color.primary.opacity(0.2) : Color.white.opacity(0.1)
    }
    
    var body: some View {
        // Background is now handled by containerBackground
        Group {
            if family == .systemMedium {
                HStack(spacing: 0) {
                    // LEFT SIDE: Status & Geometry
                    HStack(spacing: 16) {
                        vesselView
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .font(.caption2)
                                    .foregroundStyle(hydrationLabelColor)
                                Text("HYDRATION")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .fixedSize() // Prevent truncation
                            }
                            
                            Text(entry.date.formatted(.dateTime.weekday().day().month()).uppercased())
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(dateTextColor)
                                .padding(.leading, 16) // Align with text above (icon width + spacing)
                            
                            Spacer()
                            
                            Text("\(Int(entry.waterIntake))")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(isAccented ? Color.primary : Color.white)
                                .contentTransition(.numericText(value: Double(entry.waterIntake)))
                                .widgetAccentable()
                            
                            Text("/ \(Int(entry.dailyGoal)) oz")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // DIVIDER
                    Rectangle()
                        .fill(dividerColor)
                        .frame(width: 1)
                        .padding(.vertical, 16)
                    
                    // RIGHT SIDE: Simplified Actions
                    VStack(spacing: 8) {
                        // +8 Button (Primary)
                        Button(intent: LogWaterIntent(amount: 8)) {
                            HStack {
                                Text("+8 oz")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Spacer()
                                Image(systemName: "drop.fill")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(buttonBackground8oz, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(buttonForeground8oz)
                        }
                        .buttonStyle(.plain)
                        
                        // +16 Button (Secondary)
                        Button(intent: LogWaterIntent(amount: 16)) {
                             HStack {
                                Text("+16 oz")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Spacer()
                                Image(systemName: "drop.fill")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(buttonBackground16oz, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(buttonForeground16oz)
                        }
                        .buttonStyle(.plain)
                        
                        // - Subtract (Tertiary)
                        Button(intent: LogWaterIntent(amount: -8)) {
                            HStack {
                                Text("-8 oz")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Spacer()
                                Image(systemName: "minus")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(buttonBackgroundMinus, in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(buttonForegroundMinus)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .frame(width: 135) // Increased width to prevent truncation
                }
            } else {
                // Small Layout
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .font(.caption2)
                            .foregroundStyle(hydrationLabelColor)
                        Text("Hydration")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 12)
                    
                    HStack {
                        Text(entry.date.formatted(.dateTime.weekday().month().day()).uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(dateTextColor)
                            .padding(.leading, 16) // Align with text
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 2)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        vesselView
                            .scaleEffect(0.85) // Slightly smaller to make room
                        
                        VStack(spacing: 6) {
                            Text("\(Int(entry.waterIntake))")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(isAccented ? Color.primary : Color.white)
                                .contentTransition(.numericText(value: Double(entry.waterIntake)))
                                .widgetAccentable()
                            
                            // Stacked Buttons for Small
                            Button(intent: LogWaterIntent(amount: 8)) {
                                Image(systemName: "plus")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 28, height: 28)
                                    .background(isAccented ? Color.primary.opacity(0.2) : Color.cyan.opacity(0.2), in: Circle())
                                    .foregroundStyle(isAccented ? Color.primary : Color.white)
                            }
                            .buttonStyle(.plain)
                            
                            Button(intent: LogWaterIntent(amount: -8)) {
                                Image(systemName: "minus")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 28, height: 28)
                                    .background(isAccented ? Color.primary.opacity(0.1) : Color.white.opacity(0.15), in: Circle())
                                    .foregroundStyle(isAccented ? Color.primary.opacity(0.8) : Color.gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .containerBackground(for: .widget) {
            if isAccented {
                Color.clear // Let system handle background in accented mode
            } else {
                ZStack {
                    Color(red: 0.05, green: 0.05, blue: 0.07)
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.15), Color.blue.opacity(0.1), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }
    
    var vesselView: some View {
        ZStack(alignment: .bottom) {
            // Glass Vessel Shell (Fill)
            GlassShape()
                .fill(isAccented ? Color.primary.opacity(0.1) : Color.white.opacity(0.1))
                .frame(width: 50, height: 75)
            
            // Glass Vessel Shell (Stroke)
            GlassShape()
                .stroke(
                    isAccented ? Color.primary.opacity(0.3) : .white.opacity(0.2),
                    lineWidth: 1
                )
                .frame(width: 50, height: 75)
            
            // Water Level
            ZStack(alignment: .bottom) {
                 Color.clear.frame(width: 50, height: 75)
                 
                 GlassShape()
                    .fill(
                        isAccented ? AnyShapeStyle(Color.primary.opacity(0.8)) : AnyShapeStyle(gradientWater)
                    )
                    .frame(width: 50)
                    .frame(height: 75 * waterFillHeight)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: waterFillHeight)
                    .widgetAccentable() // Ensure water picks up tint
            }
            .clipShape(GlassShape()) // Mask to glass shape
            .frame(width: 50, height: 75, alignment: .bottom)
            
            // Glint/Reflection
            GlassShape()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .clear, .white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: 50, height: 75)
                .opacity(isAccented ? 0.3 : 1.0) // Reduce glint in accented mode
        }
        .shadow(color: isAccented ? .clear : .cyan.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// Tapered Glass Shape
struct GlassShape: InsettableShape {
    var insetAmount: CGFloat = 0
    
    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
    
    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        
        // Configuration
        let topWidth: CGFloat = insetRect.width
        let bottomWidth: CGFloat = insetRect.width * 0.75 // Tapered bottom
        let cornerRadius: CGFloat = 8
        
        let taperInset = (topWidth - bottomWidth) / 2
        
        // Coordinates relative to the insetRect
        path.move(to: CGPoint(x: insetRect.minX, y: insetRect.minY)) // Top Left
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.minY)) // Top Right
        
        // Bottom Right with corner
        path.addLine(to: CGPoint(x: insetRect.maxX - taperInset, y: insetRect.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.maxX - taperInset - cornerRadius, y: insetRect.maxY),
            control: CGPoint(x: insetRect.maxX - taperInset, y: insetRect.maxY)
        )
        
        // Bottom Left with corner
        path.addLine(to: CGPoint(x: insetRect.minX + taperInset + cornerRadius, y: insetRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.minX + taperInset, y: insetRect.maxY - cornerRadius),
            control: CGPoint(x: insetRect.minX + taperInset, y: insetRect.maxY)
        )
        
        path.closeSubpath()
        return path
    }
}
