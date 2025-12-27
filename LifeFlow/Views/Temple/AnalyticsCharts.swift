//
//  AnalyticsCharts.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Time Scope Enum

enum TimeScope: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var id: String { rawValue }
    
    /// Number of days to display
    var dayCount: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
    
    /// X-axis stride unit for charts
    var strideUnit: Calendar.Component {
        switch self {
        case .week: return .day
        case .month: return .weekOfMonth
        case .year: return .month
        }
    }
}

// MARK: - Hydration Chart

struct HydrationChart: View {
    let logs: [DayLog]
    let scope: TimeScope
    
    var filteredLogs: [DayLog] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch scope {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now)!
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now)!
        }
        
        return logs.filter { $0.date >= startDate }.sorted { $0.date < $1.date }
    }
    
    /// For month/year views, aggregate by week/month
    var aggregatedData: [(date: Date, intake: Double)] {
        let calendar = Calendar.current
        
        switch scope {
        case .week:
            // Show individual days
            return filteredLogs.map { ($0.date, $0.waterIntake) }
            
        case .month:
            // Aggregate by week
            var weeklyData: [Date: Double] = [:]
            for log in filteredLogs {
                let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: log.date))!
                weeklyData[weekStart, default: 0] += log.waterIntake
            }
            return weeklyData.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
            
        case .year:
            // Aggregate by month
            var monthlyData: [Date: Double] = [:]
            for log in filteredLogs {
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: log.date))!
                monthlyData[monthStart, default: 0] += log.waterIntake
            }
            return monthlyData.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                Text("Hydration")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            if filteredLogs.isEmpty {
                EmptyChartState(message: "No hydration data for this period")
            } else {
                Chart {
                    ForEach(aggregatedData, id: \.date) { data in
                        BarMark(
                            x: .value("Date", data.date, unit: scope == .week ? .day : (scope == .month ? .weekOfYear : .month)),
                            y: .value("Intake", data.intake)
                        )
                        .foregroundStyle(.cyan.gradient)
                        .cornerRadius(4)
                    }
                    
                    // Goal line (64oz daily, adjusted for aggregation)
                    let goalValue: Double = scope == .week ? 64 : (scope == .month ? 64 * 7 : 64 * 30)
                    RuleMark(y: .value("Goal", goalValue))
                        .foregroundStyle(.cyan.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatAxisLabel(for: date))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Double.self) {
                                Text("\(Int(intValue))oz")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatAxisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch scope {
        case .week:
            formatter.dateFormat = "E"  // Mon, Tue, etc.
        case .month:
            formatter.dateFormat = "M/d" // 1/15
        case .year:
            formatter.dateFormat = "MMM" // Jan, Feb, etc.
        }
        return formatter.string(from: date)
    }
}

// MARK: - Goal Progress Chart

struct GoalProgressChart: View {
    let goal: Goal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.green)
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            
            Chart {
                // Ideal trajectory line (start to deadline)
                LineMark(
                    x: .value("Date", goal.startDate),
                    y: .value("Progress", 0),
                    series: .value("Type", "Ideal")
                )
                .foregroundStyle(.green.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                
                LineMark(
                    x: .value("Date", goal.deadline ?? Date()),
                    y: .value("Progress", goal.targetAmount),
                    series: .value("Type", "Ideal")
                )
                .foregroundStyle(.green.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                
                // Actual progress from entries
                let sortedEntries = goal.entries.sorted { $0.date < $1.date }
                var cumulative: Double = 0
                
                // Start point
                PointMark(
                    x: .value("Date", goal.startDate),
                    y: .value("Progress", 0)
                )
                .foregroundStyle(.green)
                .symbolSize(50)
                
                // Plot cumulative progress
                ForEach(Array(sortedEntries.enumerated()), id: \.offset) { index, entry in
                    let _ = (cumulative += entry.valueAdded)
                    
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Progress", cumulative),
                        series: .value("Type", "Actual")
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Progress", cumulative)
                    )
                    .foregroundStyle(.green)
                    .symbolSize(30)
                }
                
                // Current position marker
                PointMark(
                    x: .value("Date", Date()),
                    y: .value("Progress", goal.currentAmount)
                )
                .foregroundStyle(.green)
                .symbolSize(100)
                .annotation(position: .top) {
                    Text("\(Int(goal.currentAmount))/\(Int(goal.targetAmount))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            .frame(height: 180)
            .chartXScale(domain: goal.startDate...(goal.deadline ?? Date()))
            .chartYScale(domain: 0...goal.targetAmount)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Consistency Heatmap

struct ConsistencyHeatmap: View {
    let logs: [DayLog]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    /// Days to show in heatmap (last 28 days = 4 weeks)
    private let dayCount = 28
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(.green)
                Text("Consistency")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            Text("Days with all targets met")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Weekday labels
            let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
            HStack(spacing: 4) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<dayCount, id: \.self) { index in
                    let daysAgo = dayCount - 1 - index
                    let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
                    let log = logs.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
                    let intensity = calculateIntensity(for: log)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(intensityColor(intensity))
                        .frame(height: 20)
                        .overlay {
                            if Calendar.current.isDateInToday(date) {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(.primary.opacity(0.3), lineWidth: 1)
                            }
                        }
                }
            }
            
            // Legend
            HStack(spacing: 8) {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensityColor(level))
                        .frame(width: 12, height: 12)
                }
                
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func calculateIntensity(for log: DayLog?) -> Double {
        guard let log = log else { return 0 }
        
        var score: Double = 0
        
        // Hydration: 64oz = full credit
        score += min(log.waterIntake / 64.0, 1.0) * 0.5
        
        // Workout: any workout = half credit
        if log.hasWorkedOut { score += 0.5 }
        
        return score
    }
    
    private func intensityColor(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color.primary.opacity(0.1)
        }
        return Color.green.opacity(0.2 + (intensity * 0.6))
    }
}

// MARK: - Empty State

struct EmptyChartState: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }
}
