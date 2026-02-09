//
//  AppReviewManager.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import Foundation
import StoreKit
import UIKit

/// Handles guarded, context-aware in-app review requests.
final class AppReviewManager {
    static let shared = AppReviewManager()
    
    enum TriggerReason {
        case longRun
        case personalBest
    }
    
    private let defaults = UserDefaults.standard
    private let lastPromptDateKey = "lifeflow.review.lastPromptDate"
    private let promptCountKey = "lifeflow.review.promptCount"
    private let maxPromptCount = 3
    private let cooldownDays = 120
    
    private init() {}
    
    func requestReviewIfEligible(reason: TriggerReason) {
        guard canPromptNow else { return }
        
        Task { @MainActor in
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            
            if #available(iOS 18.0, *) {
                AppStore.requestReview(in: scene)
            } else {
                SKStoreReviewController.requestReview(in: scene)
            }
            markPrompted()
            print("Requested App Store review for reason: \(reason)")
        }
    }
    
    private var canPromptNow: Bool {
        let promptCount = defaults.integer(forKey: promptCountKey)
        guard promptCount < maxPromptCount else { return false }
        
        guard let lastPromptDate = defaults.object(forKey: lastPromptDateKey) as? Date else {
            return true
        }
        
        let daysSincePrompt = Calendar.current.dateComponents([.day], from: lastPromptDate, to: Date()).day ?? 0
        return daysSincePrompt >= cooldownDays
    }
    
    private func markPrompted() {
        defaults.set(Date(), forKey: lastPromptDateKey)
        defaults.set(defaults.integer(forKey: promptCountKey) + 1, forKey: promptCountKey)
    }
}
