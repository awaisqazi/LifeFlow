//
//  DailyEntry.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation
import SwiftData

@Model
final class DailyEntry {
    var date: Date
    var valueAdded: Double
    
    @Relationship(inverse: \Goal.entries) var goal: Goal?
    @Relationship(inverse: \DayLog.entries) var dayLog: DayLog?
    
    init(date: Date = .now, valueAdded: Double) {
        self.date = date
        self.valueAdded = valueAdded
    }
}
