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
    
    /// Vertical tilt offset (-1.0 to 1.0)
    /// Represents the device's pitch (forward-back tilt)
    private(set) var pitchOffset: Double = 0
    
    /// Whether motion updates are currently active
    private(set) var isActive: Bool = false
    
    // MARK: - Private Properties
    
    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 1.0 / 60.0  // 60 Hz
    private let maxTiltAngle: Double = 0.5  // Clamp for realistic motion
    
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
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // Extract attitude (device orientation relative to reference frame)
            let attitude = motion.attitude
            
            // Roll: rotation around the X-axis (tilting phone left/right)
            // Pitch: rotation around the Y-axis (tilting phone forward/back)
            
            // Normalize and clamp roll for water surface tilt
            let normalizedRoll = attitude.roll / .pi  // -1 to 1
            let clampedRoll = max(-self.maxTiltAngle, min(self.maxTiltAngle, normalizedRoll))
            
            // Normalize and clamp pitch for additional motion
            let normalizedPitch = attitude.pitch / .pi  // -1 to 1
            let clampedPitch = max(-self.maxTiltAngle, min(self.maxTiltAngle, normalizedPitch))
            
            // Smooth interpolation for fluid motion
            self.tiltAngle = self.tiltAngle * 0.8 + clampedRoll * 0.2
            self.pitchOffset = self.pitchOffset * 0.8 + clampedPitch * 0.2
        }
        
        isActive = true
    }
    
    /// Stop receiving motion updates
    func stopMotionUpdates() {
        guard isActive else { return }
        
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        
        // Smoothly reset to neutral
        tiltAngle = 0
        pitchOffset = 0
    }
    
    /// Simulate a splash effect (for add water animation)
    func triggerSplash() {
        // Create a temporary disturbance in tilt
        let originalTilt = tiltAngle
        tiltAngle = originalTilt + 0.15
        
        // Reset after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.tiltAngle = originalTilt - 0.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.tiltAngle = originalTilt
        }
    }
}
