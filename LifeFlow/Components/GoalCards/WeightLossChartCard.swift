//
//  WeightLossChartCard.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import SwiftUI
import Charts

/// A visualization card showing a line graph with trend vs goal line.
/// Area between lines is shaded green (good - below goal) or red (behind).
struct WeightLossChartCard: View {
    let goal: Goal
    
    private var plan: DailyPlan {
        goal.dailyPlan
    }
    
    /// Generate chart data points
    private var chartData: [WeightDataPoint] {
        generateChartData()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "scalemass.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text(goal.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                StatusBadge(status: plan.status)
            }
            
            // Chart
            Chart {
                // Goal line (dashed)
                ForEach(chartData.filter { $0.type == .goal }) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.value)
                    )
                    .foregroundStyle(.gray.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
                
                // Trend line (solid)
                ForEach(chartData.filter { $0.type == .actual }) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.value)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
                
                // Area between lines
                ForEach(chartData.filter { $0.type == .actual }) { point in
                    if let goalPoint = chartData.first(where: { $0.type == .goal && Calendar.current.isDate($0.date, inSameDayAs: point.date) }) {
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Actual", point.value),
                            yEnd: .value("Goal", goalPoint.value)
                        )
                        .foregroundStyle(
                            point.value < goalPoint.value 
                                ? Color.green.opacity(0.3)
                                : Color.red.opacity(0.3)
                        )
                    }
                }
            }
            .frame(height: 180)
            .chartYScale(domain: chartYDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            
            // Legend
            HStack(spacing: 16) {
                LegendItem(color: .blue, label: "Actual")
                LegendItem(color: .gray, label: "Goal", isDashed: true)
                LegendItem(color: .green.opacity(0.5), label: "Ahead", isArea: true)
                LegendItem(color: .red.opacity(0.5), label: "Behind", isArea: true)
            }
            .font(.caption)
            
            Divider()
            
            // Stats row
            HStack {
                StatItem(
                    title: "Current",
                    value: "\(String(format: "%.1f", goal.currentAmount)) lbs",
                    color: .primary
                )
                
                Spacer()
                
                StatItem(
                    title: "Target",
                    value: "\(String(format: "%.1f", goal.targetAmount)) lbs",
                    color: .secondary
                )
                
                Spacer()
                
                StatItem(
                    title: "To Lose",
                    value: "\(String(format: "%.1f", max(0, goal.currentAmount - goal.targetAmount))) lbs",
                    color: plan.status == .ahead ? .green : (plan.status == .behind ? .orange : .blue)
                )
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }
    
    // MARK: - Chart Data Generation
    
    private func generateChartData() -> [WeightDataPoint] {
        var data: [WeightDataPoint] = []
        let calendar = Calendar.current
        
        let startDate = goal.startDate
        let endDate = goal.deadline ?? Date().addingTimeInterval(86400 * 30)
        let totalDays = max(1, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 30)
        
        // Starting weight (current + what's been lost, or use startValue)
        let startingWeight = goal.startValue ?? (goal.currentAmount + 10)
        let targetWeight = goal.targetAmount
        let weightToLose = startingWeight - targetWeight
        
        // Generate goal line (linear)
        for dayOffset in stride(from: 0, through: totalDays, by: 7) {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                let progress = Double(dayOffset) / Double(totalDays)
                let goalWeight = startingWeight - (weightToLose * progress)
                data.append(WeightDataPoint(date: date, value: goalWeight, type: .goal))
            }
        }
        
        // Generate actual trend (using entries or simulated)
        let daysElapsed = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        
        if goal.entries.isEmpty {
            // Simulate trend based on current amount
            for dayOffset in stride(from: 0, through: min(daysElapsed, totalDays), by: 7) {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                    let progress = Double(dayOffset) / Double(max(daysElapsed, 1))
                    let actualWeight = startingWeight - ((startingWeight - goal.currentAmount) * progress)
                    // Add some variance
                    let variance = Double.random(in: -0.5...0.5)
                    data.append(WeightDataPoint(date: date, value: actualWeight + variance, type: .actual))
                }
            }
        } else {
            // Use actual entries
            let sortedEntries = goal.entries.sorted { $0.date < $1.date }
            for entry in sortedEntries {
                data.append(WeightDataPoint(date: entry.date, value: entry.valueAdded, type: .actual))
            }
        }
        
        return data
    }
    
    private var chartYDomain: ClosedRange<Double> {
        let startingWeight = goal.startValue ?? (goal.currentAmount + 10)
        let targetWeight = goal.targetAmount
        let minWeight = min(startingWeight, targetWeight) - 5
        let maxWeight = max(startingWeight, targetWeight) + 5
        return minWeight...maxWeight
    }
}

// MARK: - Data Models

struct WeightDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let type: DataPointType
    
    enum DataPointType {
        case goal
        case actual
    }
}

// MARK: - Supporting Views

struct LegendItem: View {
    let color: Color
    let label: String
    var isDashed: Bool = false
    var isArea: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            if isArea {
                Rectangle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .cornerRadius(2)
            } else {
                Rectangle()
                    .fill(color)
                    .frame(width: 16, height: isDashed ? 2 : 3)
                    .overlay {
                        if isDashed {
                            HStack(spacing: 2) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: 2, height: 2)
                                }
                            }
                        }
                    }
            }
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        WeightLossChartCard(goal: Goal(
            title: "Weight Goal",
            targetAmount: 160,
            currentAmount: 175,
            startDate: Date().addingTimeInterval(-86400 * 30),
            deadline: Date().addingTimeInterval(86400 * 60),
            type: .weightLoss,
            startValue: 185
        ))
        .padding()
    }
    .preferredColorScheme(.dark)
}
