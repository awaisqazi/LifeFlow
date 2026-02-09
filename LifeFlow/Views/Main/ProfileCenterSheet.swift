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
    @State private var showingFeedback: Bool = false
    @State private var experienceSettings: LifeFlowExperienceSettings = .load()
    
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LifeFlow Beta")
                                .font(.subheadline.weight(.semibold))
                            Text("Polish pass in progress")
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
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ProfileCenterSheet()
}
