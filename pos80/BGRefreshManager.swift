// BGRefreshManager.swift — Background task scheduler for offline order sync
import BackgroundTasks
import Foundation

enum BGRefreshManager {
    static let syncTaskId = "com.ampos.pos80.sync"

    /// Register background task handlers — must be called at launch before app finishes launching.
    static func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: syncTaskId, using: .main) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleSync(task: processingTask)
        }
    }

    /// Schedule next background sync (requires network, 15 min earliest start).
    static func scheduleSync() {
        let request = BGProcessingTaskRequest(identifier: syncTaskId)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Not a fatal error — sync will run on next foreground
        }
    }

    private static func handleSync(task: BGProcessingTask) {
        let syncTask = Task {
            await OfflineManager.shared.syncPendingOrders()
            scheduleSync() // Reschedule for next cycle
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            syncTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
