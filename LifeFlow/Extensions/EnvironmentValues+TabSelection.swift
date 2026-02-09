//
//  EnvironmentValues+TabSelection.swift
//  LifeFlow
//
//  Created by Codex on 2/9/26.
//

import SwiftUI

private struct OpenTabKey: EnvironmentKey {
    static let defaultValue: (LifeFlowTab) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Switches to a top-level tab from child views.
    var openTab: (LifeFlowTab) -> Void {
        get { self[OpenTabKey.self] }
        set { self[OpenTabKey.self] = newValue }
    }
}
