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
    var entry: SimpleEntry
    
    @Environment(\.widgetFamily) var family

    var waterFillHeight: CGFloat {
        let percentage = min(entry.waterIntake / entry.dailyGoal, 1.0)
        return CGFloat(percentage)
    }

    var body: some View {
        // Background is now handled by containerBackground
        Group {
            if family == .systemMedium {
                HStack(spacing: 20) {
                    vesselView
                        .padding(.vertical, 12)
                        .padding(.leading, 12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "drop.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.cyan)
                            Text("Hydration")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(entry.waterIntake))")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText(value: Double(entry.waterIntake)))
                            Text("oz")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        Text("Goal: \(Int(entry.dailyGoal)) oz")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            // Subtract Button
                            Button(intent: LogWaterIntent(amount: -8)) {
                                Image(systemName: "minus")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 32, height: 32)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)

                            // Custom Input (Deep Link)
                            Link(destination: URL(string: "lifeflow://log-water")!) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 32, height: 32)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            
                            // Add Button
                            Button(intent: LogWaterIntent(amount: 8)) {
                                HStack(spacing: 2) {
                                    Image(systemName: "plus")
                                    Text("8")
                                }
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .shadow(color: .cyan.opacity(0.3), radius: 4, x: 0, y: 2)
                                )
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.trailing, 12)
                    
                    Spacer()
                }
            } else {
                // Small Layout
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.cyan)
                        Text("Hydration")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        vesselView
                            .scaleEffect(0.9)
                        
                        VStack(spacing: 8) {
                            Text("\(Int(entry.waterIntake))")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText(value: Double(entry.waterIntake)))
                            
                            // Stacked Buttons for Small
                            Button(intent: LogWaterIntent(amount: 8)) {
                                Image(systemName: "plus")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 28, height: 28)
                                    .background(Color.cyan.gradient, in: Circle())
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            
                            Button(intent: LogWaterIntent(amount: -8)) {
                                Image(systemName: "minus")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 28, height: 28)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .containerBackground(for: .widget) {
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
    
    var vesselView: some View {
        ZStack(alignment: .bottom) {
            // Glass Vessel Shell
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
                .frame(width: 50, height: 75) // Fixed height explicit
            
            // Water Level
            ZStack(alignment: .bottom) {
                 // Background of water (empty state to hold frame? No, just mask)
                 Color.clear.frame(width: 48, height: 73)
                 
                 RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 48)
                    .frame(height: 73 * waterFillHeight) // Explicit height calculation
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: waterFillHeight)
            }
            .frame(width: 48, height: 73, alignment: .bottom) // Constrain container
            .padding(.bottom, 1)

            // Glint/Reflection
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .clear, .white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: 50, height: 75)
        }
        .shadow(color: .cyan.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}
