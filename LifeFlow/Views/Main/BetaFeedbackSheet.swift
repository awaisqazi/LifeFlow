//
//  BetaFeedbackSheet.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI
import UIKit

/// Captures tester feedback with optional diagnostic snapshot for TestFlight debugging.
struct BetaFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.marathonCoachManager) private var coachManager
    @Environment(\.gymModeManager) private var gymModeManager
    
    @State private var notes: String = ""
    @State private var includeDiagnostics: Bool = true
    @State private var hasCopied: Bool = false
    
    private var reportText: String {
        var lines: [String] = []
        lines.append("LifeFlow TestFlight Feedback")
        lines.append("Generated: \(Date.now.formatted(date: .abbreviated, time: .standard))")
        lines.append("App: \(appVersionString)")
        lines.append("")
        lines.append("Issue Notes:")
        lines.append(notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "- No notes entered." : notes)
        
        if includeDiagnostics {
            lines.append("")
            lines.append("Diagnostics:")
            lines.append(trainingPlanSnapshot)
        }
        
        return lines.joined(separator: "\n")
    }
    
    private var appVersionString: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(shortVersion) (\(build))"
    }
    
    private var trainingPlanSnapshot: String {
        var lines: [String] = []
        
        if let plan = coachManager.activePlan {
            lines.append("- Plan ID: \(plan.id.uuidString)")
            lines.append("- Active: \(plan.isActive), Completed: \(plan.isCompleted)")
            lines.append("- Race: \(plan.raceDistance.rawValue), Race Date: \(plan.raceDate.formatted(date: .abbreviated, time: .omitted))")
            lines.append("- Week/Total: \(plan.currentWeek)/\(plan.totalWeeks), Day/Total: \(plan.currentDay)/\(plan.totalDays)")
            lines.append("- Compliance: \(String(format: "%.2f", plan.complianceScore)), Confidence: \(String(format: "%.2f", plan.confidenceScore))")
            
            if let session = plan.todaysSession {
                lines.append("- Today: \(session.runType.displayName), target \(String(format: "%.2f", session.targetDistance)) mi, completed \(session.isCompleted)")
                if let actual = session.actualDistance {
                    lines.append("- Today Actual: \(String(format: "%.2f", actual)) mi, effort \(session.perceivedEffort?.description ?? "-")")
                }
            } else {
                lines.append("- Today: No scheduled session.")
            }
        } else {
            lines.append("- No active training plan.")
        }
        
        lines.append("- Gym Target: \(gymModeManager.activeTarget.displayName)")
        lines.append("- Indoor Run Mode: \(gymModeManager.isIndoorRun)")
        lines.append("- Voice Coach Muted: \(gymModeManager.isVoiceCoachMuted)")
        
        return lines.joined(separator: "\n")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What happened?")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        TextEditor(text: $notes)
                            .frame(minHeight: 160)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Toggle("Include TrainingPlan diagnostics", isOn: $includeDiagnostics)
                        .font(.subheadline.weight(.medium))
                    
                    VStack(spacing: 10) {
                        ShareLink(item: reportText) {
                            Label("Share Feedback", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button {
                            UIPasteboard.general.string = reportText
                            hasCopied = true
                        } label: {
                            Label(hasCopied ? "Copied" : "Copy Report", systemImage: hasCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(reportText)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .background(SanctuaryTimeBackdrop(includeMeshOverlay: true))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("Beta Feedback")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    BetaFeedbackSheet()
}

