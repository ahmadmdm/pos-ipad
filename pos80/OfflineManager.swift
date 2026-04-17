// OfflineManager.swift — Offline order queue & auto-sync when back online
import Foundation
import Network
import Combine

/// Manages offline order persistence and auto-sync when connectivity restores
@MainActor
final class OfflineManager: ObservableObject {

    static let shared = OfflineManager()
    private let api = APIService.shared
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "offline.monitor")
    private let storageKey = "offline_pending_orders"

    @Published var isOnline = true
    @Published var pendingCount = 0
    @Published var isSyncing = false
    @Published var lastSyncAt: Date?
    @Published var lastSyncError: String?

    private init() {
        loadPending()
        startMonitoring()
    }

    // MARK: - Network Monitoring
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = self?.isOnline == false
                self?.isOnline = path.status == .satisfied
                AppState.shared.syncManagerSnapshotWithLocalState()
                if wasOffline && path.status == .satisfied {
                    await self?.syncPendingOrders()
                }
            }
        }
        monitor.start(queue: queue)
        Task { @MainActor in
            self.isOnline = monitor.currentPath.status == .satisfied
            AppState.shared.syncManagerSnapshotWithLocalState()
        }
    }

    // MARK: - Persistence
    private var pendingOrders: [OfflineOrder] {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let orders = try? JSONDecoder().decode([OfflineOrder].self, from: data) else { return [] }
            return orders
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: storageKey)
            }
            pendingCount = newValue.filter { !$0.synced }.count
        }
    }

    private func loadPending() {
        pendingCount = pendingOrders.filter { !$0.synced }.count
    }

    var queueSnapshot: [OfflineOrder] {
        pendingOrders.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Queue Order for Later Sync
    func queueOrder(_ order: OrderCreate, paymentMethod: String, cashTendered: Double?) {
        var orders = pendingOrders
        orders.append(OfflineOrder(
            localId: order.localId ?? UUID().uuidString,
            orderCreate: order,
            paymentMethod: paymentMethod,
            cashTendered: cashTendered,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            synced: false
        ))
        pendingOrders = orders
        // Schedule offline sync reminder (fires after 10 minutes if still offline)
        NotificationManager.shared.scheduleOfflineSyncAlert(pendingCount: pendingCount)
        NotificationManager.shared.notifyOfflineBacklogThreshold(pendingCount: pendingCount)
        AppState.shared.syncManagerSnapshotWithLocalState()
    }

    // MARK: - Sync All Pending
    func syncPendingOrders() async {
        guard !isSyncing else { return }
        let unsynced = pendingOrders.filter { !$0.synced }
        guard !unsynced.isEmpty else { return }

        isSyncing = true
        lastSyncError = nil
        AppState.shared.syncManagerSnapshotWithLocalState()
        var orders = pendingOrders

        for pending in unsynced {
            do {
                // Create the order
                let order = try await api.createOrder(pending.orderCreate)
                // Pay it
                let payment = OrderPayment(
                    paymentMethod: pending.paymentMethod,
                    paymentReference: nil,
                    cashTendered: pending.cashTendered
                )
                _ = try await api.payOrder(order.id, payment: payment)

                // Mark synced
                if let idx = orders.firstIndex(where: { $0.localId == pending.localId }) {
                    orders[idx].synced = true
                }
            } catch {
                print("[OfflineSync] Failed to sync order \(pending.localId): \(error)")
                lastSyncError = error.localizedDescription
                // Leave unsynced for next try
            }
        }

        pendingOrders = orders
        // Clean up old synced orders (keep last 50)
        let synced = orders.filter { $0.synced }
        if synced.count > 50 {
            let toRemove = synced.prefix(synced.count - 50)
            pendingOrders = orders.filter { o in !toRemove.contains(where: { $0.localId == o.localId }) }
        }
        isSyncing = false
        lastSyncAt = Date()
        // If all orders are now synced, cancel the pending notification
        if pendingCount == 0 {
            NotificationManager.shared.cancelOfflineSyncAlert()
            NotificationManager.shared.cancelOfflineSyncFailureAlert()
        } else if lastSyncError != nil {
            NotificationManager.shared.notifyOfflineSyncFailure(
                pendingCount: pendingCount,
                message: lastSyncError
            )
        }
        AppState.shared.syncManagerSnapshotWithLocalState()
        BGRefreshManager.scheduleSync()
    }

    func retrySyncNow() async {
        await syncPendingOrders()
    }
}

// MARK: - Offline Order Model
struct OfflineOrder: Codable, Identifiable {
    var id: String { localId }
    let localId: String
    let orderCreate: OrderCreate
    let paymentMethod: String
    let cashTendered: Double?
    let createdAt: String
    var synced: Bool
}
