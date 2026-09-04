import SwiftUI
import UIKit
import SwiftData

final class AdatAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { @MainActor in
            await APNsRegistrationBridge.shared.refreshRegistrationIfAuthorized()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            APNsRegistrationBridge.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        NSLog("APNs registration failed: \(error.localizedDescription)")
        #endif
    }
}

@main
struct sunnad_iosApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AdatAppDelegate.self) private var appDelegate

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
                    dependencies.notificationInteractionTracker.register()
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
