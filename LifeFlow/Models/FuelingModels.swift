//
//  FuelingModels.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import Foundation
import SwiftUI

enum NutrientType: String, CaseIterable, Codable {
    case carbs = "Carbs"
    case protein = "Protein"
    case electrolytes = "Salts"
    
    var color: Color {
        switch self {
        case .carbs: return .orange
        case .protein: return .mint
        case .electrolytes: return .cyan
        }
    }
    
    var icon: String {
        switch self {
        case .carbs: return "bolt.fill"
        case .protein: return "figure.strengthtraining.traditional"
        case .electrolytes: return "drop.fill"
        }
    }
}

struct FuelItem: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let type: NutrientType
    
    init(
        id: String? = nil,
        name: String,
        description: String,
        icon: String,
        type: NutrientType
    ) {
        self.id = id ?? Self.makeID(from: name)
        self.name = name
        self.description = description
        self.icon = icon
        self.type = type
    }
    
    private static func makeID(from raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

struct FuelTimelineEntry: Identifiable, Hashable {
    let id: String
    let minutesOffset: Int
    let title: String
    let subtitle: String
    let type: NutrientType
    
    var offsetLabel: String {
        if minutesOffset == 0 { return "Start" }
        let sign = minutesOffset > 0 ? "+" : ""
        return "\(sign)\(minutesOffset)m"
    }
}

struct FuelingStrategy {
    let timeline: [FuelTimelineEntry]
    let preRun: [FuelItem]
    let intraRun: [FuelItem]
    let postRun: [FuelItem]
    let pantryEssentials: [FuelItem]
    let estimatedRunMinutes: Int?
    
    var hasIntraRunFuel: Bool {
        !intraRun.isEmpty
    }
    
    static func forSession(_ session: TrainingSession) -> FuelingStrategy {
        let estimatedRunMinutes = MarathonPaceDefaults.estimatedDurationMinutes(
            distanceMiles: session.targetDistance,
            runType: session.runType
        )
        
        let isLongRun = session.runType == .longRun
            || session.targetDistance >= 8
            || (estimatedRunMinutes ?? 0) >= 65
        
        let isQualitySession = session.runType == .tempo || session.runType == .speedWork
        
        if session.runType == .rest {
            return FuelingStrategy(
                timeline: [
                    FuelTimelineEntry(id: "rest-hydrate", minutesOffset: 0, title: "Recovery Day", subtitle: "Hydrate steadily", type: .electrolytes)
                ],
                preRun: [],
                intraRun: [],
                postRun: [
                    FuelItem(name: "Balanced Plate", description: "Colorful carbs + protein to refill glycogen.", icon: "fork.knife.circle.fill", type: .carbs),
                    FuelItem(name: "Electrolyte Water", description: "Keep salts stable through the day.", icon: "waterbottle.fill", type: .electrolytes)
                ],
                pantryEssentials: Self.defaultPantryEssentials,
                estimatedRunMinutes: estimatedRunMinutes
            )
        }
        
        if session.runType == .crossTraining {
            return FuelingStrategy(
                timeline: [
                    FuelTimelineEntry(id: "cross-pre", minutesOffset: -60, title: "Pre-Session", subtitle: "Light carb primer", type: .carbs),
                    FuelTimelineEntry(id: "cross-post", minutesOffset: 0, title: "Post-Session", subtitle: "Protein + fluids", type: .protein)
                ],
                preRun: [
                    FuelItem(name: "Toast & Nut Butter", description: "Stable fuel 60 mins before training.", icon: "leaf.fill", type: .carbs)
                ],
                intraRun: [],
                postRun: [
                    FuelItem(name: "Protein Smoothie", description: "Support recovery from strength or circuits.", icon: "cup.and.saucer.fill", type: .protein),
                    FuelItem(name: "Electrolyte Mix", description: "Replenish sodium and fluids.", icon: "drop.degreesign.fill", type: .electrolytes)
                ],
                pantryEssentials: Self.defaultPantryEssentials,
                estimatedRunMinutes: estimatedRunMinutes
            )
        }
        
        if isLongRun {
            return FuelingStrategy(
                timeline: [
                    FuelTimelineEntry(id: "long-preload", minutesOffset: -120, title: "Pre-Load", subtitle: "Slow carbs", type: .carbs),
                    FuelTimelineEntry(id: "long-ignite", minutesOffset: -30, title: "Ignition", subtitle: "Fast carbs", type: .carbs),
                    FuelTimelineEntry(id: "long-during", minutesOffset: 45, title: "On-Run Fuel", subtitle: "Every 30-40 mins", type: .electrolytes),
                    FuelTimelineEntry(id: "long-recovery", minutesOffset: 0, title: "Recovery", subtitle: "Protein + fluids", type: .protein)
                ],
                preRun: [
                    FuelItem(name: "Oatmeal Bowl", description: "Slow-release energy 2 hours pre-run.", icon: "bowl.fill", type: .carbs),
                    FuelItem(name: "Banana", description: "Potassium + easy carbs 30 mins out.", icon: "leaf.fill", type: .carbs)
                ],
                intraRun: [
                    FuelItem(name: "Energy Gel", description: "Take around mile 6, then every 30-40 mins.", icon: "bolt.heart.fill", type: .carbs),
                    FuelItem(name: "Electrolyte Sip", description: "Small regular sips to hold sodium balance.", icon: "water.waves", type: .electrolytes)
                ],
                postRun: [
                    FuelItem(name: "Protein Smoothie", description: "Immediate repair window nutrition.", icon: "cup.and.saucer.fill", type: .protein),
                    FuelItem(name: "Salt + Fruit", description: "Restore glycogen and minerals.", icon: "applelogo", type: .electrolytes)
                ],
                pantryEssentials: Self.defaultPantryEssentials,
                estimatedRunMinutes: estimatedRunMinutes
            )
        }
        
        if isQualitySession {
            return FuelingStrategy(
                timeline: [
                    FuelTimelineEntry(id: "quality-prime", minutesOffset: -90, title: "Prime", subtitle: "Steady carbs", type: .carbs),
                    FuelTimelineEntry(id: "quality-ignite", minutesOffset: -30, title: "Ignition", subtitle: "Quick carbs", type: .carbs),
                    FuelTimelineEntry(id: "quality-recovery", minutesOffset: 0, title: "Recovery", subtitle: "Protein + hydration", type: .protein)
                ],
                preRun: [
                    FuelItem(name: "Toast & Honey", description: "Digestible carbs before faster running.", icon: "birthday.cake.fill", type: .carbs),
                    FuelItem(name: "Espresso & Dates", description: "Small boost 20-30 mins before.", icon: "cup.and.saucer.fill", type: .carbs)
                ],
                intraRun: estimatedRunMinutes ?? 0 > 60
                    ? [FuelItem(name: "Half Gel", description: "Optional if session runs long.", icon: "bolt.fill", type: .carbs)]
                    : [],
                postRun: [
                    FuelItem(name: "Greek Yogurt + Fruit", description: "Protein with light carbs to reload.", icon: "takeoutbag.and.cup.and.straw.fill", type: .protein)
                ],
                pantryEssentials: Self.defaultPantryEssentials,
                estimatedRunMinutes: estimatedRunMinutes
            )
        }
        
        return FuelingStrategy(
            timeline: [
                FuelTimelineEntry(id: "base-pre", minutesOffset: -90, title: "Pre-Load", subtitle: "Light carbs", type: .carbs),
                FuelTimelineEntry(id: "base-ignite", minutesOffset: -30, title: "Ignition", subtitle: "Simple carb", type: .carbs),
                FuelTimelineEntry(id: "base-recovery", minutesOffset: 0, title: "Recovery", subtitle: "Hydrate + protein", type: .protein)
            ],
            preRun: [
                FuelItem(name: "Toast & Banana", description: "Light, stable energy before your run.", icon: "leaf.fill", type: .carbs)
            ],
            intraRun: [],
            postRun: [
                FuelItem(name: "Electrolytes", description: "Replenish salts and fluids.", icon: "drop.fill", type: .electrolytes),
                FuelItem(name: "Protein Snack", description: "Small repair signal within 45 mins.", icon: "takeoutbag.and.cup.and.straw.fill", type: .protein)
            ],
            pantryEssentials: Self.defaultPantryEssentials,
            estimatedRunMinutes: estimatedRunMinutes
        )
    }
    
    private static let defaultPantryEssentials: [FuelItem] = [
        FuelItem(name: "Bananas", description: "Potassium support", icon: "leaf.fill", type: .carbs),
        FuelItem(name: "Rolled Oats", description: "Slow carbs for long energy", icon: "bowl.fill", type: .carbs),
        FuelItem(name: "Dates", description: "Fast carbs pre-run", icon: "bolt.fill", type: .carbs),
        FuelItem(name: "Electrolytes", description: "Hydration and salt balance", icon: "drop.fill", type: .electrolytes),
        FuelItem(name: "Whey/Plant Protein", description: "Post-run repair", icon: "figure.strengthtraining.traditional", type: .protein)
    ]
}
