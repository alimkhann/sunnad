import SwiftUI
import WidgetKit

@main
struct SunnadWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayChecklistWidget()
        QuickToggleWidget()
        ProgressWidget()
        GroupsWidget()
        DhikrCounterWidget()
    }
}
