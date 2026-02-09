//
//  VoiceCoach.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import AVFoundation
import Foundation

@MainActor
final class VoiceCoach: NSObject {
    private let synthesizer = AVSpeechSynthesizer()

    private(set) var announceDistance: Bool = true
    private(set) var announcePace: Bool = true
    private(set) var isMuted: Bool = false

    private var lastAnnouncedMile: Int = 0
    private var announcedHalfMileCheckpoints: Set<Int> = []
    private var lastAnnouncementDate: Date?

    private let cooldown: TimeInterval = 25

    func configure(from settings: MarathonCoachSettings) {
        announceDistance = settings.announceDistance
        announcePace = settings.announcePace
        isMuted = !settings.isVoiceCoachEnabled || settings.voiceCoachStartupMode == .muted
        configureAudioSession()
    }

    func resetSession() {
        lastAnnouncedMile = 0
        announcedHalfMileCheckpoints.removeAll()
        lastAnnouncementDate = nil
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        resetSession()
    }
    
    func stopCurrentPrompt() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func checkIn(currentDistance: Double, currentPace: Double, targetPace: Double) {
        guard currentDistance.isFinite,
              currentPace.isFinite,
              targetPace.isFinite,
              currentDistance >= 0,
              currentPace > 0,
              targetPace > 0 else {
            return
        }

        let mile = Int(floor(currentDistance))
        if announceDistance, mile > lastAnnouncedMile {
            let paceDiff = currentPace - targetPace
            let status: String
            if paceDiff > 0.5 {
                status = "You're a bit behind target."
            } else if paceDiff < -0.5 {
                status = "You're ahead of target pace."
            } else {
                status = "You're locked on target pace."
            }

            if speak("Mile \(mile) complete. \(status) Keep it flowing.") {
                lastAnnouncedMile = mile
                return
            }
        }

        let checkpoint = Int(floor(currentDistance / 0.5))
        let checkpointDistance = Double(checkpoint) * 0.5
        let paceDelta = abs(currentPace - targetPace)

        if announcePace,
           checkpoint > 0,
           !announcedHalfMileCheckpoints.contains(checkpoint),
           currentDistance >= checkpointDistance,
           paceDelta >= 0.75 {
            let message = "Check your pace. Target is \(formatPace(targetPace)) per mile."
            if speak(message) {
                announcedHalfMileCheckpoints.insert(checkpoint)
            }
        }
    }

    @discardableResult
    private func speak(_ text: String) -> Bool {
        guard !isMuted else { return false }
        guard !synthesizer.isSpeaking else { return false }

        let now = Date()
        if let lastAnnouncementDate,
           now.timeIntervalSince(lastAnnouncementDate) < cooldown {
            return false
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
        lastAnnouncementDate = now
        return true
    }

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.mixWithOthers, .duckOthers]
            )
            try audioSession.setActive(true, options: [])
        } catch {
            print("VoiceCoach audio session configuration failed: \(error)")
        }
    }

    private func formatPace(_ value: Double) -> String {
        let totalSeconds = Int((value * 60).rounded())
        let minutes = max(0, totalSeconds / 60)
        let seconds = max(0, totalSeconds % 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}
