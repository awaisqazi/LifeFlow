import WidgetKit
import SwiftUI

@main
struct LifeFlowWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LifeFlowRunComplicationWidget()
        LifeFlowQuickControlWidget()
        LifeFlowFuelControlWidget()
    }
}
