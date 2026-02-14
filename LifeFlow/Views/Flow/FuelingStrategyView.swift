//
//  FuelingStrategyView.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI
import SwiftData

struct FuelingStrategyView: View {
    let session: TrainingSession
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayLog.date, order: .reverse) private var dayLogs: [DayLog]
    @State private var completedItems: Set<String> = []
    @State private var showPantrySheet: Bool = false
    @State private var hasLoadedPersistedChecklist: Bool = false
    
    private var strategy: FuelingStrategy {
        FuelingStrategy.forSession(session)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroCard
                    fuelingTimelineCard
                    
                    if !strategy.preRun.isEmpty {
                        stageSection(
                            title: "Pre-Run",
                            subtitle: "Build steady energy before you head out.",
                            items: strategy.preRun
                        )
                    }
                    
                    if !strategy.intraRun.isEmpty {
                        stageSection(
                            title: "On-Run",
                            subtitle: "Top up energy on longer sessions.",
                            items: strategy.intraRun
                        )
                    }
                    
                    if !strategy.postRun.isEmpty {
                        stageSection(
                            title: "Recovery",
                            subtitle: "Refuel for adaptation after the run.",
                            items: strategy.postRun
                        )
                    }
                    
                    Button {
                        showPantrySheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                            Text("Open Runner's Pantry")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cyan.gradient, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .background(
                LiquidBackgroundView()
                    .opacity(0.28)
                    .ignoresSafeArea()
            )
            .navigationTitle("Fuel Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPantrySheet) {
                SmartGrocerySheet(items: strategy.pantryEssentials)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                ensureSessionDayLogExists()
                loadPersistedChecklist()
            }
            .onChange(of: completedItems) { _, _ in
                persistChecklist()
            }
        }
    }
    
    private var sessionDayStart: Date {
        Calendar.current.startOfDay(for: session.date)
    }
    
    private var sessionDayLog: DayLog? {
        dayLogs.first { Calendar.current.isDate($0.date, inSameDayAs: sessionDayStart) }
    }
    
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(session.runType.displayName, systemImage: session.runType.icon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.cyan)
                Spacer()
                Text(String(format: "%.1f mi", session.targetDistance))
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
            
            Text("Fuel by timing, not tracking. Keep it light, intentional, and run-ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let minutes = strategy.estimatedRunMinutes {
                Label("Estimated run: \(minutes) mins", systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
    
    private var fuelingTimelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fueling Timeline")
                .font(.headline.weight(.semibold))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(strategy.timeline) { entry in
                        FuelTimelineChip(entry: entry)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func stageSection(title: String, subtitle: String, items: [FuelItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 10) {
                ForEach(items) { item in
                    NutritionCardView(
                        item: item,
                        isChecked: Binding(
                            get: { completedItems.contains(item.id) },
                            set: { isChecked in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    if isChecked {
                                        completedItems.insert(item.id)
                                    } else {
                                        completedItems.remove(item.id)
                                    }
                                }
                            }
                        )
                    )
                }
            }
        }
        .padding()
        .liquidGlassCard(cornerRadius: 18)
    }
    
    private func ensureSessionDayLogExists() {
        guard sessionDayLog == nil else { return }
        let newLog = DayLog(date: sessionDayStart)
        modelContext.insert(newLog)
        try? modelContext.save()
    }
    
    private func loadPersistedChecklist() {
        ensureSessionDayLogExists()
        completedItems = sessionDayLog?.fuelChecklist(for: session.id) ?? []
        hasLoadedPersistedChecklist = true
    }
    
    private func persistChecklist() {
        guard hasLoadedPersistedChecklist else { return }
        ensureSessionDayLogExists()
        guard let sessionDayLog else { return }
        
        sessionDayLog.setFuelChecklist(completedItems, for: session.id)
        try? modelContext.save()
    }
}

private struct FuelTimelineChip: View {
    let entry: FuelTimelineEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: entry.type.icon)
                    .font(.caption.weight(.bold))
                Text(entry.offsetLabel)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(entry.type.color)
            
            Text(entry.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Text(entry.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(width: 150, alignment: .leading)
        .padding(12)
        .background(entry.type.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(entry.type.color.opacity(0.35), lineWidth: 1)
        )
    }
}

struct NutritionCardView: View {
    let item: FuelItem
    @Binding var isChecked: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.type.color.opacity(0.2))
                    .frame(width: 46, height: 46)
                
                Image(systemName: item.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(item.type.color)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 8)
            
            Button {
                isChecked.toggle()
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isChecked ? .green : .secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct SmartGrocerySheet: View {
    let items: [FuelItem]
    
    @Environment(\.dismiss) private var dismiss
    @State private var checkedItems: Set<String> = []
    
    private var sortedItems: [FuelItem] {
        items.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Runner's Pantry")
                        .font(.largeTitle.bold())
                    
                    Text("Tap ingredients you already have. Keep your fuel station stocked and simple.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(sortedItems) { item in
                            GroceryTile(
                                item: item,
                                isSelected: checkedItems.contains(item.id)
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if checkedItems.contains(item.id) {
                                        checkedItems.remove(item.id)
                                    } else {
                                        checkedItems.insert(item.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(
                LiquidBackgroundView()
                    .opacity(0.24)
                    .ignoresSafeArea()
            )
            .navigationTitle("Smart Grocery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct GroceryTile: View {
    let item: FuelItem
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.type.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            
            Spacer(minLength: 0)
            
            Text(item.name)
                .font(.headline)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(2)
            
            Text(item.description)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(height: 116)
        .background(
            isSelected
                ? AnyShapeStyle(item.type.color.gradient)
                : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? .white.opacity(0.28) : .white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: isSelected ? item.type.color.opacity(0.35) : .clear, radius: 10, y: 6)
    }
}

#Preview {
    let sampleSession = TrainingSession(
        date: .now,
        runType: .longRun,
        targetDistance: 10
    )
    return FuelingStrategyView(session: sampleSession)
}
