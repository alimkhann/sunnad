import SwiftUI
import UIKit
import SwiftData

@main
struct sunnad_iosApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let dependencies = DependencyContainer()
    private let backgroundSyncScheduler: BackgroundSyncScheduler

    init() {
        backgroundSyncScheduler = BackgroundSyncScheduler(
            syncCoordinator: dependencies.syncCoordinator,
            logger: dependencies.analyticsLogger
        )
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor.systemGroupedBackground
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor.systemGroupedBackground
        navAppearance.shadowColor = UIColor.separator.withAlphaComponent(0.22)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some Scene {
        WindowGroup {
            SunnadRootView(dependencies: dependencies)
                .tint(SunnadTheme.primary)
                .onAppear {
                    backgroundSyncScheduler.register()
                    backgroundSyncScheduler.schedule()
                }
        }
        .modelContainer(dependencies.modelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                backgroundSyncScheduler.schedule()
            }
        }
    }
}
