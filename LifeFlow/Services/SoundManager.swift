//
//  SoundManager.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import Foundation
import AVFoundation
import UIKit

/// Centralized lightweight audio + haptic feedback for sanctuary interactions.
final class SoundManager {
    static let shared = SoundManager()
    
    enum SoundEffect: String {
        case waterSplash = "water_splash"
        case glassTap = "glass_tap"
        case successChime = "success_chime"
        case startGun = "start_gun"
    }
    
    private var players: [String: AVAudioPlayer] = [:]
    
    private init() {
        configureAudioSessionIfPossible()
    }
    
    func play(_ effect: SoundEffect, volume: Float = 0.6) {
        guard let url = resolvedURL(for: effect.rawValue) else { return }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = max(0, min(volume, 1))
            player.prepareToPlay()
            player.play()
            players[effect.rawValue] = player
        } catch {
            print("SoundManager play error for \(effect.rawValue): \(error)")
        }
    }
    
    func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    private func configureAudioSessionIfPossible() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Ambient respects silent mode while still allowing subtle UI sounds with other audio.
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            print("SoundManager audio session config failed: \(error)")
        }
    }
    
    private func resolvedURL(for resourceName: String) -> URL? {
        let extensions = ["wav", "mp3", "aif", "aiff", "m4a"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: resourceName, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}

