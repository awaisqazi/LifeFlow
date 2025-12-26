//
//  UnitType.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation

enum UnitType: String, Codable, CaseIterable {
    case currency
    case weight
    case count
    case volume
    case time
    
    var symbol: String {
        switch self {
        case .currency: return "$"
        case .weight: return "lbs"
        case .count: return ""
        case .volume: return "oz"
        case .time: return "min"
        }
    }
}
