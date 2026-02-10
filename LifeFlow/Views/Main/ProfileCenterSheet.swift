//
//  ProfileCenterSheet.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI

/// Lightweight profile hub for settings and TestFlight feedback entry points.
struct ProfileCenterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.marathonCoachManager) private var coachManager
    @State private var showingFeedback: Bool = false
    @State private var experienceSettings: LifeFlowExperienceSettings = .load()
    
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    HStack(spacing: 10) {
                        ZStack(alignment: .bottomTrailing) {
                            Image("icon_runner_fluid")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                )
                                .shadow(color: .cyan.opacity(0.25), radius: 10)

                            Image("medal_early_bird")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                                .offset(x: 3, y: 3)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LifeFlow Beta")
                                .font(.subheadline.weight(.semibold))
                            Text("Early Adopter")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("TestFlight") {
                    Button {
                        showingFeedback = true
                    } label: {
                        Label("Report a Bug", systemImage: "ladybug.fill")
                    }
                    .foregroundStyle(.primary)
                    
                    Text("Include feedback notes plus automatic training-plan diagnostics to speed up debugging.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Experience") {
                    Picker("Micro-Delight", selection: $experienceSettings.microDelightIntensity) {
                        ForEach(MicroDelightIntensity.allCases) { intensity in
                            Text(intensity.displayName).tag(intensity)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Controls celebration animation intensity across tabs, hydration, and workout completion.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Power Mantra")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(
                            "e.g., Relentless Forward Motion",
                            text: Binding(
                                get: { coachManager.settings.mantra },
                                set: { newValue in
                                    coachManager.settings.mantra = String(newValue.prefix(80))
                                }
                            )
                        )
                        .font(.headline)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Mindset")
                } footer: {
                    Text("The Voice Coach will whisper this when you drift off pace in harder segments.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(SanctuaryTimeBackdrop(includeMeshOverlay: true))
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFeedback) {
                BetaFeedbackSheet()
            }
            .onChange(of: experienceSettings.microDelightIntensity) { _, _ in
                experienceSettings.save()
            }
            .onAppear {
                coachManager.reloadSettings()
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ProfileCenterSheet()
}
