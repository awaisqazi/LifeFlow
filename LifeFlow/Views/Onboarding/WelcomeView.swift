//
//  WelcomeView.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI
import UserNotifications

/// First-run launch experience that introduces LifeFlow and requests integrations with context.
struct WelcomeView: View {
    let onComplete: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var stage: Stage = .intro
    @State private var meshSpeed: Double = 2.6
    @State private var pulseIntensity: Double = 0.78
    
    @State private var hasRequestedIntegrations: Bool = false
    @State private var isRequestingIntegrations: Bool = false
    @State private var healthKitGranted: Bool = false
    @State private var notificationsGranted: Bool = false
    @State private var healthKitMessage: String?
    @State private var notificationMessage: String?
    
    private enum Stage {
        case intro
        case integration
    }
    
    var body: some View {
        ZStack {
            AnimatedMeshGradientView(
                theme: .flow,
                successPulseIntensity: pulseIntensity,
                animationSpeed: meshSpeed
            )
            .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.14),
                    Color.black.opacity(0.48)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 26) {
                Spacer()
                
                VStack(spacing: 10) {
                    Text("LifeFlow")
                        .font(.system(size: 58, weight: .bold, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.78)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text("Your rhythm, your sanctuary.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                
                switch stage {
                case .intro:
                    introPanel
                case .integration:
                    integrationPanel
                }
                
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 36)
        }
        .onAppear {
            animateLaunchCalm()
        }
    }
    
    private var introPanel: some View {
        VStack(spacing: 18) {
            Text("We’ll tune your app around your real training rhythm, then ask for integrations with full context.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.84))
                .padding(.horizontal, 4)
            
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
                    stage = .integration
                    meshSpeed = reduceMotion ? 1.0 : 0.95
                    pulseIntensity = 0.18
                }
            } label: {
                Text("Let’s Flow")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 26)
    }
    
    private var integrationPanel: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enable Integrations")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                
                Text("HealthKit powers live run sensing and history sync. Notifications keep plan nudges timely.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if hasRequestedIntegrations {
                VStack(spacing: 10) {
                    permissionRow(
                        title: "HealthKit",
                        granted: healthKitGranted,
                        fallbackMessage: healthKitMessage
                    )
                    permissionRow(
                        title: "Notifications",
                        granted: notificationsGranted,
                        fallbackMessage: notificationMessage
                    )
                }
                .transition(.opacity)
            }
            
            Button {
                Task {
                    await requestIntegrations()
                }
            } label: {
                HStack(spacing: 8) {
                    if isRequestingIntegrations {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(0.85)
                    }
                    Text(isRequestingIntegrations ? "Requesting Access…" : (hasRequestedIntegrations ? "Refresh Integrations" : "Enable Integration"))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isRequestingIntegrations)
            
            Button {
                onComplete()
            } label: {
                Text(hasRequestedIntegrations ? "Enter Sanctuary" : "Skip for Now")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 26)
    }
    
    private func permissionRow(title: String, granted: Bool, fallbackMessage: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: granted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
                .font(.caption.weight(.bold))
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                
                if granted {
                    Text("Connected")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                } else if let fallbackMessage, !fallbackMessage.isEmpty {
                    Text(fallbackMessage)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Not enabled yet")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func animateLaunchCalm() {
        let initialSpeed = reduceMotion ? 1.0 : 2.8
        let finalSpeed = reduceMotion ? 1.0 : 1.15
        
        meshSpeed = initialSpeed
        pulseIntensity = reduceMotion ? 0.2 : 0.82
        
        withAnimation(.easeOut(duration: 1.8)) {
            meshSpeed = finalSpeed
            pulseIntensity = 0.24
        }
    }
    
    private func requestIntegrations() async {
        guard !isRequestingIntegrations else { return }
        
        isRequestingIntegrations = true
        defer { isRequestingIntegrations = false }
        
        do {
            try await AppDependencyManager.shared.healthKitManager.requestAuthorization()
            healthKitGranted = true
            healthKitMessage = nil
        } catch {
            healthKitGranted = false
            healthKitMessage = error.localizedDescription
        }
        
        let notificationResult = await requestNotificationAccess()
        notificationsGranted = notificationResult.granted
        notificationMessage = notificationResult.message
        
        hasRequestedIntegrations = true
    }
    
    private func requestNotificationAccess() async -> (granted: Bool, message: String?) {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error {
                    continuation.resume(returning: (false, error.localizedDescription))
                } else {
                    continuation.resume(returning: (granted, granted ? nil : "Permission was not granted."))
                }
            }
        }
    }
}

#Preview {
    WelcomeView(onComplete: {})
        .preferredColorScheme(.dark)
}

