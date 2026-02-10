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
    private var audioRouteObserver: NSObjectProtocol?
    private var isAudioSessionActiveForSpeech: Bool = false
    var onSpeakingStateChange: ((Bool) -> Void)?

    private(set) var announceDistance: Bool = true
    private(set) var announcePace: Bool = true
    private(set) var isMuted: Bool = false
    private(set) var mantra: String = MarathonCoachSettings.defaultMantra

    private var lastAnnouncedMile: Int = 0
    private var announcedHalfMileCheckpoints: Set<Int> = []
    private var lastAnnouncementDate: Date?

    private let cooldown: TimeInterval = 25
    
    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
        startObservingAudioRouteChangesIfNeeded()
    }

    func configure(from settings: MarathonCoachSettings) {
        announceDistance = settings.announceDistance
        announcePace = settings.announcePace
        isMuted = !settings.isVoiceCoachEnabled || settings.voiceCoachStartupMode == .muted
        mantra = normalizedMantra(settings.mantra)
        configureAudioSession()
        startObservingAudioRouteChangesIfNeeded()
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
            deactivateAudioSessionAfterSpeech()
            onSpeakingStateChange?(false)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        deactivateAudioSessionAfterSpeech()
        onSpeakingStateChange?(false)
        resetSession()
    }
    
    func stopCurrentPrompt() {
        synthesizer.stopSpeaking(at: .immediate)
        deactivateAudioSessionAfterSpeech()
        onSpeakingStateChange?(false)
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
                status = mantra.isEmpty ? "You're a bit behind target." : "You're a bit behind target. \(mantra)."
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
            let isBehind = currentPace - targetPace >= 0.75
            let mantraLine = isBehind && !mantra.isEmpty ? " \(mantra)." : ""
            let message = "Check your pace. Target is \(formatPace(targetPace)) per mile.\(mantraLine)"
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

        activateAudioSessionForSpeechIfNeeded()
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
                options: [.mixWithOthers, .duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
        } catch {
            print("VoiceCoach audio session configuration failed: \(error)")
        }
    }

    private func activateAudioSessionForSpeechIfNeeded() {
        guard !isAudioSessionActiveForSpeech else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            isAudioSessionActiveForSpeech = true
        } catch {
            print("VoiceCoach audio session activation failed: \(error)")
        }
    }

    private func deactivateAudioSessionAfterSpeech() {
        guard isAudioSessionActiveForSpeech else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("VoiceCoach audio session deactivation failed: \(error)")
        }
        isAudioSessionActiveForSpeech = false
    }
    
    private func startObservingAudioRouteChangesIfNeeded() {
        guard audioRouteObserver == nil else { return }
        
        audioRouteObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.configureAudioSession()
            }
        }
    }
    
    deinit {
        if let audioRouteObserver {
            NotificationCenter.default.removeObserver(audioRouteObserver)
        }
    }

    private func formatPace(_ value: Double) -> String {
        let totalSeconds = Int((value * 60).rounded())
        let minutes = max(0, totalSeconds / 60)
        let seconds = max(0, totalSeconds % 60)
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func normalizedMantra(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return MarathonCoachSettings.defaultMantra }
        return String(trimmed.prefix(80))
    }
}

extension VoiceCoach: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onSpeakingStateChange?(true)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onSpeakingStateChange?(false)
            self?.deactivateAudioSessionAfterSpeech()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.onSpeakingStateChange?(false)
            self?.deactivateAudioSessionAfterSpeech()
        }
    }
}
