//
//  WaterManager.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/26/25.
//

import Foundation
import CoreMotion
import Observation

/// Manages CoreMotion updates for realistic water physics.
/// Tracks device pitch and roll to animate water tilting in the vessel.
@Observable
final class WaterManager {
    // MARK: - Published Properties
    
    /// Tilt angle for water surface rotation (-1.0 to 1.0)
    /// Represents the device's roll (side-to-side tilt)
    private(set) var tiltAngle: Double = 0
    
    /// Spring-smoothed tilt value used for shader binding.
    private(set) var smoothedTilt: Double = 0
    
    /// Vertical tilt offset (-1.0 to 1.0)
    /// Represents the device's pitch (forward-back tilt)
    private(set) var pitchOffset: Double = 0
    
    /// Raw gravity vector from accelerometer (normalized)
    /// X: left/right tilt, Y: forward/back tilt
    private(set) var gravityVector: SIMD2<Float> = SIMD2(0, 1)
    
    /// Whether motion updates are currently active
    private(set) var isActive: Bool = false
    
    // MARK: - Private Properties
    
    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 1.0 / 60.0  // 60 Hz
    private let maxTiltAngle: Double = 0.8  // Clamp for dramatic motion
    
    /// Spring simulation state (Hooke + damping)
    private var targetTilt: Double = 0
    private var velocity: Double = 0
    private let springStiffness: Double = 0.12
    private let springDamping: Double = 0.88
    
    // MARK: - Lifecycle
    
    init() {
        // Check if device motion is available
        guard motionManager.isDeviceMotionAvailable else {
            print("WaterManager: Device motion not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = updateInterval
    }
    
    deinit {
        stopMotionUpdates()
    }
    
    // MARK: - Public Methods
    
    /// Start receiving motion updates from CoreMotion
    func startMotionUpdates() {
        guard !isActive, motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            
            // Extract attitude (device orientation relative to reference frame)
            let attitude = motion.attitude
            
            // Extract raw gravity vector for shader physics
            let gravity = motion.gravity
            self.gravityVector = SIMD2(Float(gravity.x), Float(gravity.y))
            let rawTilt = self.clampTilt(gravity.x)
            self.targetTilt = rawTilt
            
            let force = (self.targetTilt - self.smoothedTilt) * self.springStiffness
            self.velocity = (self.velocity + force) * self.springDamping
            self.smoothedTilt = self.clampTilt(self.smoothedTilt + self.velocity)
            self.tiltAngle = self.smoothedTilt
            
            // Normalize and clamp pitch for additional motion
            let normalizedPitch = attitude.pitch / .pi  // -1 to 1
            let clampedPitch = self.clampTilt(normalizedPitch)
            self.pitchOffset = self.pitchOffset * 0.75 + clampedPitch * 0.25
        }
        
        isActive = true
    }
    
    /// Stop receiving motion updates
    func stopMotionUpdates() {
        guard isActive else { return }
        
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        
        // Smoothly reset to neutral
        targetTilt = 0
        velocity = 0
        smoothedTilt = 0
        tiltAngle = 0
        pitchOffset = 0
    }
    
    /// Direction for splash animation
    enum SplashDirection {
        case up    // Adding water - splash rises
        case down  // Removing water - splash drops
    }
    
    /// Simulate a splash effect with directional animation
    /// - Parameter direction: `.up` for adding water, `.down` for removing
    func triggerSplash(direction: SplashDirection = .up) {
        let originalTilt = targetTilt
        let multiplier: Double = direction == .up ? 1.0 : -1.0
        
        // Create a temporary disturbance in the spring target.
        targetTilt = clampTilt(originalTilt + (0.15 * multiplier))
        smoothedTilt = targetTilt
        tiltAngle = smoothedTilt
        velocity = 0
        
        // Bounce back effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.targetTilt = self?.clampTilt(originalTilt - (0.1 * multiplier)) ?? 0
        }
        
        // Settle to original
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.targetTilt = self?.clampTilt(originalTilt + (0.05 * multiplier)) ?? 0
        }
        
        // Final settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.targetTilt = originalTilt
        }
    }
    
    private func clampTilt(_ value: Double) -> Double {
        max(-maxTiltAngle, min(maxTiltAngle, value))
    }
}
