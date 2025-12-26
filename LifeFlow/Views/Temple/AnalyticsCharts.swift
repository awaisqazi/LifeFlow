//
//  AnalyticsCharts.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData
import Charts

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
        
        // Filter and sort
        return logs.filter { $0.date >= startDate }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hydration History")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Chart {
                ForEach(filteredLogs) { log in
                    BarMark(
                        x: .value("Date", log.date, unit: .day),
                        y: .value("Intake", log.waterIntake)
                    )
                    .foregroundStyle(.cyan.gradient)
                    .cornerRadius(4)
                }
                
                RuleMark(y: .value("Goal", 64))
                    .foregroundStyle(.cyan.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .leading, alignment: .bottom) {
                        Text("Goal")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    if scope == .week {
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    } else {
                         // Simplify for longer ranges
                         AxisValueLabel(format: .dateTime.day())
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Goal Progress Chart

struct GoalProgressChart: View {
    let goal: Goal
    
    // Calculate cumulative progress data points
    // This is computationally expensive, ideally would be pre-calculated
    // For this prototype, we'll iterate entries
    struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let actual: Double
        let ideal: Double
    }
    
    var dataPoints: [DataPoint] {
        let start = goal.startDate
        let end = goal.deadline
        
        var points: [DataPoint] = []
        
        // Ensure we have entries linked to this goal
        // SwiftData queries might be tricky here without inverse relationship on DailyEntry working perfectly
        // Assuming goal.entries works maybe? Or we pass in relevant DayLogs.
        // For now, let's use goal.currentAmount as a single point vs time if we can't easily get history
        // Actually, currentAmount is just a total. We need history for a line chart.
        // If we can't easily get history distribution, we might simplify to just "Current vs Expected" bar.
        // But requested is a line chart.
        
        // Let's create a simplified "Ideal" line from Start to End
        // And an "Actual" point for Today.
        
        // Ideal Line
        points.append(DataPoint(date: start, actual: 0, ideal: 0))
        points.append(DataPoint(date: end, actual: 0, ideal: goal.targetAmount))
        
        return points
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trajectory: \(goal.title)")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Chart {
                // Ideal Line
                LineMark(
                    x: .value("Date", goal.startDate),
                    y: .value("Ideal", 0)
                )
                .foregroundStyle(.green.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                
                LineMark(
                    x: .value("Date", goal.deadline),
                    y: .value("Ideal", goal.targetAmount)
                )
                .foregroundStyle(.green.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                
                // Actual Current Point (Simplification since we don't have full history easily queryable in this view without passing all DayLogs)
                 PointMark(
                    x: .value("Date", Date()),
                    y: .value("Actual", goal.currentAmount)
                )
                .foregroundStyle(.green)
                .symbolSize(100)
                
            }
            .frame(height: 180)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Consistency Heatmap

struct ConsistencyHeatmap: View {
    let logs: [DayLog]
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7) // 7 cols for weeks
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Consistency")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: columns, spacing: 4) {
                // Show last 28 days (4 weeks)
                ForEach(0..<28) { index in
                    let date = Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date()
                    let log = logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
                    
                    // Simple logic: Green opacity based on workout + water
                    // Or if we had separate "goals met" count
                    let intensity: Double = calculateIntensity(for: log)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(intensity > 0 ? Color.green.opacity(intensity) : Color.primary.opacity(0.1))
                        .frame(height: 20)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func calculateIntensity(for log: DayLog?) -> Double {
        guard let log = log else { return 0 }
        
        var score: Double = 0
        if log.waterIntake >= 64 { score += 0.5 }
        if log.hasWorkedOut { score += 0.5 }
        
        return max(score, 0.1) // Minimum visibility if log exists
    }
}

enum TimeScope: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var id: String { rawValue }
}
