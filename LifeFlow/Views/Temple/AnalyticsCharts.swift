//
//  AnalyticsCharts.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Selected Date Wrapper

/// Wrapper to make Date conform to Identifiable for sheet presentation
struct SelectedDateWrapper: Identifiable {
    let id = UUID()
    let date: Date
}

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

// MARK: - Hydration Chart (Streak Calendar)

/// Water-themed streak calendar showing days the hydration goal was met.
/// Features interactive tap to reveal daily cup consumption.
struct HydrationChart: View {
    let logs: [DayLog]
    let scope: TimeScope
    
    @State private var selectedDate: SelectedDateWrapper?
    
    /// Daily goal from user settings
    private var dailyGoal: Double {
        HydrationSettings.load().dailyOuncesGoal
    }
    
    /// Generate array of dates for the current scope
    private var datesInScope: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        switch scope {
        case .week:
            // Saturday through Friday week
            // Find the most recent Saturday (or today if it is Saturday)
            let weekday = calendar.component(.weekday, from: today)
            // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
            // We want Saturday (7) as start of week
            let daysSinceSaturday = (weekday == 7) ? 0 : (weekday + 6) % 7 + 1
            let saturday = calendar.date(byAdding: .day, value: -daysSinceSaturday + 1, to: today)!
            
            return (0..<7).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: saturday)
            }
            
        case .month:
            // Current calendar month
            let components = calendar.dateComponents([.year, .month], from: today)
            guard let firstOfMonth = calendar.date(from: components),
                  let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
                return []
            }
            
            return (0..<range.count).compactMap { offset in
                calendar.date(byAdding: .day, value: offset, to: firstOfMonth)
            }
            
        case .year:
            // Last 365 days
            return (0..<365).compactMap { offset in
                calendar.date(byAdding: .day, value: -(364 - offset), to: today)
            }
        }
    }
    
    /// Days to display based on scope
    private var daysToShow: Int {
        datesInScope.count
    }
    
    /// Get log for a specific date
    private func logFor(_ date: Date) -> DayLog? {
        logs.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Check if goal was met for a date
    private func goalMet(for date: Date) -> Bool {
        guard let log = logFor(date) else { return false }
        return log.waterIntake >= dailyGoal
    }
    
    /// Count of days goal was met
    private var goalMetCount: Int {
        datesInScope.filter { goalMet(for: $0) }.count
    }
    
    /// Current month name for month view header
    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }
    
    /// Grid columns based on scope
    private var columns: [GridItem] {
        switch scope {
        case .week:
            return Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        case .month:
            return Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        case .year:
            // 12 months across
            return Array(repeating: GridItem(.flexible(), spacing: 2), count: 12)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with summary
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                Text("Hydration")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Goal met summary
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Text("\(goalMetCount)/\(daysToShow) days")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.15), in: Capsule())
            }
            
            // Subheader with month name for month view
            if scope == .month {
                HStack {
                    Text(currentMonthName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text("Days you hit your \(Int(dailyGoal))oz goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Days you hit your \(Int(dailyGoal))oz goal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if scope == .year {
                // Year view: monthly aggregates
                YearlyHydrationGrid(logs: logs, dailyGoal: dailyGoal)
            } else {
                // Week/Month view: day grid
                if scope == .week {
                    // Single row for week
                    HStack(spacing: 8) {
                        ForEach(datesInScope, id: \.self) { date in
                            HydrationDayTile(
                                date: date,
                                log: logFor(date),
                                dailyGoal: dailyGoal,
                                isCompact: false
                            )
                            .onTapGesture {
                                selectedDate = SelectedDateWrapper(date: date)
                            }
                        }
                    }
                } else {
                    // Grid for month
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(datesInScope, id: \.self) { date in
                            HydrationDayTile(
                                date: date,
                                log: logFor(date),
                                dailyGoal: dailyGoal,
                                isCompact: true
                            )
                            .onTapGesture {
                                selectedDate = SelectedDateWrapper(date: date)
                            }
                        }
                    }
                }
            }
            
            // Legend
            HStack(spacing: 16) {
                Spacer()
                HydrationLegendItem(color: .cyan, label: "Goal Met")
                HydrationLegendItem(color: .secondary.opacity(0.3), label: "Missed")
            }
            .font(.caption2)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .sheet(item: $selectedDate) { wrapper in
            HydrationDayDetailSheet(
                date: wrapper.date,
                log: logFor(wrapper.date),
                dailyGoal: dailyGoal
            )
            .presentationDetents([.height(300)])
        }
    }
}

// MARK: - Hydration Day Tile

/// Individual day tile for the hydration streak calendar
struct HydrationDayTile: View {
    let date: Date
    let log: DayLog?
    let dailyGoal: Double
    let isCompact: Bool
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var goalMet: Bool {
        guard let log = log else { return false }
        return log.waterIntake >= dailyGoal
    }
    
    private var waterIntake: Double {
        log?.waterIntake ?? 0
    }
    
    private var fillLevel: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(waterIntake / dailyGoal, 1.0)
    }
    
    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = isCompact ? "d" : "E"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: isCompact ? 2 : 6) {
            // Day label
            Text(dayLabel)
                .font(isCompact ? .system(size: 8) : .caption2.weight(.medium))
                .foregroundStyle(isToday ? .cyan : .secondary)
            
            // Water droplet
            ZStack {
                // Background
                Image(systemName: "drop.fill")
                    .font(isCompact ? .system(size: 16) : .title3)
                    .foregroundStyle(.secondary.opacity(0.15))
                
                // Fill based on progress
                Image(systemName: "drop.fill")
                    .font(isCompact ? .system(size: 16) : .title3)
                    .foregroundStyle(
                        goalMet
                            ? LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .top,
                                endPoint: .bottom
                              )
                            : LinearGradient(
                                colors: [.secondary.opacity(0.3), .secondary.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                              )
                    )
                    .mask(
                        GeometryReader { geo in
                            Rectangle()
                                .frame(height: geo.size.height * fillLevel)
                                .offset(y: geo.size.height * (1 - fillLevel))
                        }
                    )
                
                // Goal checkmark overlay
                if goalMet {
                    Image(systemName: "checkmark")
                        .font(.system(size: isCompact ? 6 : 10, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(y: isCompact ? 1 : 2)
                }
            }
            .frame(width: isCompact ? 20 : 32, height: isCompact ? 24 : 38)
            
            // Today indicator
            if isToday && !isCompact {
                Circle()
                    .fill(.cyan)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isCompact ? 2 : 4)
        .background(
            isToday
                ? RoundedRectangle(cornerRadius: isCompact ? 6 : 10)
                    .stroke(.cyan.opacity(0.3), lineWidth: 1)
                : nil
        )
    }
}

// MARK: - Yearly Hydration Grid

/// Monthly aggregated view for year scope
struct YearlyHydrationGrid: View {
    let logs: [DayLog]
    let dailyGoal: Double
    
    private var monthlyData: [(month: Date, daysMetGoal: Int, totalDays: Int)] {
        let calendar = Calendar.current
        var data: [(Date, Int, Int)] = []
        
        for monthOffset in stride(from: 11, through: 0, by: -1) {
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: Date()) else { continue }
            
            let components = calendar.dateComponents([.year, .month], from: monthStart)
            guard let firstOfMonth = calendar.date(from: components),
                  let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { continue }
            
            let daysInMonth = range.count
            let daysPassed: Int
            
            if calendar.isDate(monthStart, equalTo: Date(), toGranularity: .month) {
                daysPassed = calendar.component(.day, from: Date())
            } else if monthOffset == 0 {
                daysPassed = calendar.component(.day, from: Date())
            } else {
                daysPassed = daysInMonth
            }
            
            let logsInMonth = logs.filter { calendar.isDate($0.date, equalTo: firstOfMonth, toGranularity: .month) }
            let daysMetGoal = logsInMonth.filter { $0.waterIntake >= dailyGoal }.count
            
            data.append((firstOfMonth, daysMetGoal, daysPassed))
        }
        
        return data
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(monthlyData, id: \.month) { item in
                VStack(spacing: 4) {
                    // Month bar
                    let percentage = item.totalDays > 0 ? Double(item.daysMetGoal) / Double(item.totalDays) : 0
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.secondary.opacity(0.15))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: geo.size.height * percentage)
                        }
                    }
                    .frame(height: 60)
                    
                    // Month label
                    Text(monthLabel(for: item.month))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Hydration Legend Item

struct HydrationLegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "drop.fill")
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Day Detail Sheet

/// Detail sheet showing hydration for a specific day
struct HydrationDayDetailSheet: View {
    let date: Date
    let log: DayLog?
    let dailyGoal: Double
    
    @Environment(\.dismiss) private var dismiss
    
    private var cupsGoal: Int {
        HydrationSettings.load().dailyCupsGoal
    }
    
    private var cupsDrank: Int {
        Int((log?.waterIntake ?? 0) / 8)
    }
    
    private var waterIntake: Double {
        log?.waterIntake ?? 0
    }
    
    private var goalMet: Bool {
        waterIntake >= dailyGoal
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(goalMet ? Color.cyan.opacity(0.15) : Color.secondary.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: goalMet ? "drop.fill" : "drop")
                        .font(.system(size: 36))
                        .foregroundStyle(goalMet ? .cyan : .secondary)
                    
                    if goalMet {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .offset(x: 24, y: 24)
                    }
                }
                
                // Stats
                VStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 4) {
                        Text("\(cupsDrank)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(goalMet ? .cyan : .primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("cups")
                                .font(.subheadline.weight(.medium))
                            Text("of \(cupsGoal)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("\(Int(waterIntake)) / \(Int(dailyGoal)) oz")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Visual cups
                HStack(spacing: 6) {
                    ForEach(0..<cupsGoal, id: \.self) { index in
                        Image(systemName: "drop.fill")
                            .font(.title3)
                            .foregroundStyle(
                                index < cupsDrank
                                    ? Color.cyan
                                    : Color.secondary.opacity(0.2)
                            )
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
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
        
        // Hydration: goal from settings = full credit
        let hydrationGoal = HydrationSettings.load().dailyOuncesGoal
        score += min(log.waterIntake / hydrationGoal, 1.0) * 0.5
        
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
