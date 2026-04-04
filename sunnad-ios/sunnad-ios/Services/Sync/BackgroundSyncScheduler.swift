import BackgroundTasks
import Foundation

@MainActor
final class BackgroundSyncScheduler {
    static let taskIdentifier = "com.arystan.almasuly.sunnad.sync.refresh"

    private let syncCoordinator: SyncCoordinating
    private let logger: AnalyticsLogging
    private var runningTask: Task<Void, Never>?

    init(syncCoordinator: SyncCoordinating, logger: AnalyticsLogging) {
        self.syncCoordinator = syncCoordinator
        self.logger = logger
    }

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            Task { @MainActor in
                self?.handle(refreshTask)
            }
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.log(.syncFinished, metadata: ["scope": "sync_bg_schedule", "status": "submitted"])
        } catch {
            logger.log(.storageFailure, metadata: ["scope": "sync_bg_schedule", "error": error.localizedDescription])
        }
    }

    private func handle(_ task: BGAppRefreshTask) {
        schedule()

        runningTask?.cancel()
        let work = Task {
            await syncCoordinator.runSyncCycle(trigger: .background)
            task.setTaskCompleted(success: true)
        }
        runningTask = work

        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
