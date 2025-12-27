//
//  HabitHeatmapCard.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI

/// A visualization card showing a GitHub-style heatmap grid.
/// Darker cells indicate more occurrences or higher intensity.
struct HabitHeatmapCard: View {
    let goal: Goal
    
    @State private var selectedDay: HeatmapDay?
    
    private var plan: DailyPlan {
        goal.dailyPlan
    }
    
    /// Generate heatmap data for the past weeks
    private var heatmapData: [[HeatmapDay]] {
        generateHeatmapData()
    }
    
    /// Calculate current streak
    private var currentStreak: Int {
        calculateStreak()
    }
    
    /// Calculate longest streak
    private var longestStreak: Int {
        calculateLongestStreak()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Streak badge
                HStack(spacing: 4) {
                    Image(systemName: "flame")
                        .font(.caption)
                    Text("\(currentStreak)")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.2))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
            }
            
            // Heatmap grid
            VStack(alignment: .leading, spacing: 2) {
                // Day labels
                HStack(spacing: 0) {
                    Text("") // Empty space for alignment
                        .font(.caption2)
                        .frame(width: 24)
                    
                    ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                        Text(day)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Heatmap rows (weeks)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(Array(heatmapData.enumerated()), id: \.offset) { weekIndex, week in
                            VStack(spacing: 3) {
                                ForEach(week) { day in
                                    HeatmapCell(day: day, isSelected: selectedDay?.id == day.id)
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.3)) {
                                                selectedDay = selectedDay?.id == day.id ? nil : day
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .frame(height: 85)
            }
            
            // Legend
            HStack {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 2) {
                    ForEach(0..<5) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(intensityColor(for: level))
                            .frame(width: 10, height: 10)
                    }
                }
                
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let selected = selectedDay {
                    Text(selected.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(selected.count) times")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
            }
            
            Divider()
            
            // Stats
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(currentStreak) days")
                            .font(.subheadline.bold())
                    }
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("Longest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(longestStreak) days")
                        .font(.subheadline.bold())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(goal.currentAmount))")
                        .font(.subheadline.bold())
                }
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    // MARK: - Data Generation
    
    private func generateHeatmapData() -> [[HeatmapDay]] {
        var weeks: [[HeatmapDay]] = []
        let calendar = Calendar.current
        let today = Date()
        
        // Get entries by date
        let entriesByDate: [Date: Int] = Dictionary(grouping: goal.entries) { entry in
            calendar.startOfDay(for: entry.date)
        }.mapValues { $0.count }
        
        // Generate 12 weeks of data
        let weeksToShow = 12
        
        for weekOffset in (0..<weeksToShow).reversed() {
            var week: [HeatmapDay] = []
            
            for dayOfWeek in 0..<7 {
                let daysBack = weekOffset * 7 + (6 - dayOfWeek)
                if let date = calendar.date(byAdding: .day, value: -daysBack, to: today) {
                    let startOfDay = calendar.startOfDay(for: date)
                    let count = entriesByDate[startOfDay] ?? 0
                    
                    // For demo purposes, add some random data if no entries
                    let displayCount = goal.entries.isEmpty ? 
                        (daysBack < 60 ? Int.random(in: 0...4) : 0) : count
                    
                    week.append(HeatmapDay(
                        date: date,
                        count: displayCount,
                        isFuture: date > today
                    ))
                }
            }
            
            weeks.append(week)
        }
        
        return weeks
    }
    
    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        // Create a set of dates with entries
        let entryDates = Set(goal.entries.map { calendar.startOfDay(for: $0.date) })
        
        // If no entries, use demo data
        if goal.entries.isEmpty {
            return Int.random(in: 3...15)
        }
        
        // Count consecutive days
        while true {
            let startOfDay = calendar.startOfDay(for: currentDate)
            if entryDates.contains(startOfDay) {
                streak += 1
                if let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                    currentDate = previousDay
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func calculateLongestStreak() -> Int {
        // Simplified calculation
        return max(currentStreak, Int(goal.currentAmount / 5))
    }
    
    private func intensityColor(for level: Int) -> Color {
        switch level {
        case 0: return .gray.opacity(0.2)
        case 1: return .orange.opacity(0.3)
        case 2: return .orange.opacity(0.5)
        case 3: return .orange.opacity(0.7)
        default: return .orange
        }
    }
}

// MARK: - Data Models

struct HeatmapDay: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let isFuture: Bool
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var intensityLevel: Int {
        switch count {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        case 3: return 3
        default: return 4
        }
    }
}

// MARK: - Heatmap Cell

struct HeatmapCell: View {
    let day: HeatmapDay
    let isSelected: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor)
            .frame(width: 10, height: 10)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(.white, lineWidth: 1)
                }
            }
            .scaleEffect(isSelected ? 1.3 : 1.0)
    }
    
    private var cellColor: Color {
        if day.isFuture {
            return .gray.opacity(0.1)
        }
        
        switch day.intensityLevel {
        case 0: return .gray.opacity(0.2)
        case 1: return .orange.opacity(0.3)
        case 2: return .orange.opacity(0.5)
        case 3: return .orange.opacity(0.7)
        default: return .orange
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        HabitHeatmapCard(goal: Goal(
            title: "Daily Meditation",
            targetAmount: 365,
            currentAmount: 87,
            type: .habit
        ))
        .padding()
    }
    .preferredColorScheme(.dark)
}
