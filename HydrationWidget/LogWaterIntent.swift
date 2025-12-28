//
//  LogWaterIntent.swift
//  HydrationWidgetExtension
//
//  Created by Fez Qazi on 12/27/25.
//

import AppIntents
import SwiftData

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Increments daily water intake.")
    
    @Parameter(title: "Amount")
    var amount: Double
    
    init() {
        self.amount = 8.0
    }
    
    init(amount: Double) {
        self.amount = amount
    }
    
    func perform() async throws -> some IntentResult {
        let context = ModelContext(WidgetDataLayer.shared.modelContainer)
        
        // Find or create today's log
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate<DayLog> { $0.date >= today }
        )
        
        let existingLogs = try? context.fetch(descriptor)
        let dayLog = existingLogs?.first ?? DayLog(date: Date())
        
        if existingLogs?.isEmpty == true || existingLogs == nil {
            context.insert(dayLog)
        }
        
        dayLog.waterIntake = max(0, dayLog.waterIntake + amount)
        
        try? context.save()
        
        // Reload widget timeline
        return .result()
    }
}
