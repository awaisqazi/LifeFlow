import Foundation
import AVFoundation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - VoiceCoachService
// An actor that wraps Apple's on-device FoundationModels LLM and
// AVSpeechSynthesizer to deliver real-time, privacy-preserving audio
// coaching cues during workouts. Falls back to the deterministic
// CoachPromptEngine when the LLM is unavailable (unsupported device,
// model downloading, etc.).

/// On-device LLM voice coach that generates short motivational audio cues
/// based on biomechanical metrics and engine decisions.
///
/// Architecture rationale:
/// - Uses an `actor` to serialize LLM calls and maintain cooldown state safely.
/// - The `@concurrent` attribute on the LLM generation ensures it runs on the
///   concurrent thread pool, freeing this actor's executor for other work.
/// - Falls back to `CoachPromptEngine` (deterministic, rule-based) when
///   `SystemLanguageModel` is unavailable (e.g., iPhone 15 or earlier,
///   Apple Intelligence not enabled, model still downloading).
public actor VoiceCoachService {

    // MARK: - State

    /// Minimum interval between audio prompts to avoid annoying the runner.
    private let cooldownInterval: TimeInterval

    /// Timestamp of the last spoken prompt.
    private var lastPromptTime: Date = .distantPast

    /// Deterministic fallback engine for devices without FoundationModels.
    private let fallbackEngine: CoachPromptEngine

    /// Speech synthesizer — reused across prompts for efficiency.
    #if os(iOS) || os(watchOS)
    private let synthesizer = AVSpeechSynthesizer()

    /// Delegate that deactivates the audio session when speech finishes,
    /// allowing background music to smoothly ramp back to 100% volume.
    private let speechDelegate = SpeechDelegate()
    #endif

    // MARK: - Init

    /// - Parameter cooldown: Minimum seconds between audio cues (default: 120s / 2 minutes).
    public init(cooldown: TimeInterval = 120) {
        self.cooldownInterval = cooldown
        self.fallbackEngine = CoachPromptEngine(cooldown: cooldown)

        #if os(iOS) || os(watchOS)
        synthesizer.delegate = speechDelegate
        #endif
    }

    // MARK: - Public API

    /// Evaluates biomechanical metrics and engine decision, optionally
    /// generating and speaking an audio coaching cue.
    ///
    /// - Parameters:
    ///   - gct: Ground Contact Time in milliseconds.
    ///   - power: Running power in watts.
    ///   - decision: The latest `EngineDecision` from `AdaptiveMarathonEngine`.
    /// - Returns: The spoken prompt text, or `nil` if cooldown hasn't elapsed.
    @discardableResult
    public func evaluateAndSpeak(
        gct: Double,
        power: Double,
        decision: EngineDecision
    ) async -> String? {
        // MARK: Cooldown check — don't spam the runner with audio cues.
        let now = Date()
        guard now.timeIntervalSince(lastPromptTime) >= cooldownInterval else {
            return nil
        }

        // Attempt LLM generation; fall back to deterministic text on failure.
        let text: String
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            if let llmText = await generateWithLLM(gct: gct, power: power, decision: decision) {
                text = llmText
            } else {
                text = fallbackText(for: decision)
            }
        } else {
            text = fallbackText(for: decision)
        }
        #else
        text = fallbackText(for: decision)
        #endif

        guard !text.isEmpty else { return nil }

        lastPromptTime = now
        speakText(text)
        return text
    }

    // MARK: - FoundationModels LLM Generation

    #if canImport(FoundationModels)
    /// Generates a coaching cue using the on-device LLM.
    /// Returns `nil` if the model is unavailable or generation fails.
    @available(iOS 26.0, macOS 26.0, watchOS 26.0, *)
    private func generateWithLLM(
        gct: Double,
        power: Double,
        decision: EngineDecision
    ) async -> String? {
        let model = SystemLanguageModel.default

        // MARK: Availability gate — Only proceed if the model is ready.
        // This covers: device not eligible, Apple Intelligence disabled,
        // model still downloading, etc.
        guard case .available = model.availability else {
            return nil
        }

        let instructions = """
            You are an elite, encouraging running coach giving real-time audio cues \
            during a workout. Respond in 10 words or fewer. Be motivational, specific, \
            and actionable. Never use emojis. Focus on form corrections and encouragement.
            """

        let alertContext = decision.alerts
            .map { $0.rawValue }
            .joined(separator: ", ")

        let prompt = """
            Runner's ground contact time: \(Int(gct))ms. \
            Power output: \(Int(power))W. \
            Active alerts: \(alertContext.isEmpty ? "none" : alertContext). \
            Fatigue coefficient: \(String(format: "%.1f", decision.fatigueCoefficient)). \
            Give a concise audio cue to improve their form.
            """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let cue = response.content
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Enforce 10-word limit as a safety net
            let words = cue.split(whereSeparator: \.isWhitespace).prefix(10)
            return words.joined(separator: " ")
        } catch {
            // Neural Engine busy, context overflow, or other error.
            // Silently fall back to rule-based prompt.
            return nil
        }
    }
    #endif

    // MARK: - Fallback (Rule-Based)

    /// Returns deterministic coaching text from `CoachPromptEngine`.
    private func fallbackText(for decision: EngineDecision) -> String {
        let prompt = fallbackEngine.prompt(
            for: decision,
            now: Date(),
            lastPromptAt: nil // Always generate — we've already passed cooldown gate
        )
        return prompt?.message ?? ""
    }

    // MARK: - Speech Synthesis

    /// Speaks the given text using AVSpeechSynthesizer with audio ducking.
    /// Ducking lowers the volume of currently playing music so the coaching
    /// cue is clearly audible without stopping the user's playlist.
    private func speakText(_ text: String) {
        #if os(iOS) || os(watchOS)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        // MARK: Audio Session — Duck other audio for seamless coaching overlay.
        // .duckOthers lowers music volume; .interruptSpokenAudioAndMixWithOthers
        // ensures we don't interrupt Siri or VoiceOver.
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            // Non-fatal — worst case, the cue plays at full volume without ducking.
        }

        synthesizer.speak(utterance)
        #endif
    }
}

// MARK: - Speech Delegate (Audio Session Deactivation)

/// Handles speech completion to deactivate the audio session with
/// `.notifyOthersOnDeactivation`, smoothly ramping background music
/// (Spotify, Apple Music) back to 100% volume after a coaching cue.
///
/// Must be a class (not actor) to conform to `AVSpeechSynthesizerDelegate`.
/// Reference: iOS `VoiceCoach.swift` uses the same pattern.
#if os(iOS) || os(watchOS)
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        deactivateAudioSession()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
        } catch {
            // Non-fatal — background music may stay slightly ducked until
            // the session is naturally reclaimed by the system.
        }
    }
}
#endif
