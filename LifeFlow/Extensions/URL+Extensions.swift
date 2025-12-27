//
//  URL+Extensions.swift
//  LifeFlow
//
//  Created by Fez Qazi on 12/27/25.
//

import Foundation

extension URL {
    /// Returns the location of the shared App Group container.
    /// - Parameter appGroup: The App Group identifier (e.g., "group.com.Fez.LifeFlow")
    /// - Returns: The URL to the shared container, or the standard document directory if not found (fallback).
    static func storeURL(for appGroup: String) -> URL {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            fatalError("Shared file container could not be created for App Group: \(appGroup)")
        }
        return fileContainer.appendingPathComponent("LifeFlow.sqlite")
    }
}
