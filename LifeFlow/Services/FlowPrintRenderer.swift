//
//  FlowPrintRenderer.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import Foundation
import SwiftUI
import CoreLocation

enum FlowPrintFormat: String, CaseIterable, Identifiable {
    case story
    case square
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .story: return "Story"
        case .square: return "Square"
        }
    }
    
    var canvasSize: CGSize {
        switch self {
        case .story:
            return CGSize(width: 1080, height: 1920)
        case .square:
            return CGSize(width: 1080, height: 1080)
        }
    }
}

struct FlowPrintRouteSegment {
    let coordinates: [CLLocationCoordinate2D]
    let isAhead: Bool
}

struct FlowPrintRenderInput {
    let sessionTitle: String
    let runLine: String
    let durationLine: String
    let templeLine: String
    let weatherLine: String?
    let paceLine: String?
    let completionDate: Date
    let format: FlowPrintFormat
    let routeSegments: [FlowPrintRouteSegment]
}

struct FlowPrintRenderResult {
    let image: UIImage
    let fileURL: URL
    let caption: String
}

@MainActor
final class FlowPrintRenderer {
    static let shared = FlowPrintRenderer()
    
    private init() {}
    
    func renderPoster(input: FlowPrintRenderInput) throws -> FlowPrintRenderResult {
        let size = input.format.canvasSize
        
        let poster = FlowPrintPosterView(input: input)
            .frame(width: size.width, height: size.height)
            .background(Color.black)
            .environment(\.colorScheme, .dark)
        
        let renderer = ImageRenderer(content: poster)
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1
        
        guard let image = renderer.uiImage,
              let pngData = image.pngData() else {
            throw NSError(
                domain: "FlowPrintRenderer",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to render Flow Print image."]
            )
        }
        
        let filename = "flow-print-\(UUID().uuidString).png"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try pngData.write(to: fileURL, options: [.atomic])
        
        let caption = buildCaption(from: input)
        return FlowPrintRenderResult(image: image, fileURL: fileURL, caption: caption)
    }
    
    private func buildCaption(from input: FlowPrintRenderInput) -> String {
        var parts: [String] = []
        parts.append("Flow Print")
        parts.append(input.runLine)
        parts.append(input.durationLine)
        if let pace = input.paceLine, !pace.isEmpty {
            parts.append(pace)
        }
        parts.append("The Temple")
        return parts.joined(separator: " • ")
    }
}
