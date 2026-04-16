// AppState.swift — Global state management for the POS app
import SwiftUI
import LocalAuthentication

// MARK: - App Destination (navigation)
enum AppDestination: Equatable {
    case login
    case main
}

struct ManagerOperationalSnapshot: Codable {
    var hasActiveShift = false
    var activeShiftId: String?
    var openOrdersCount = 0
    var paidOrdersCount = 0
    var offlinePendingCount = 0
    var unreadBroadcastCount = 0
    var isOnline = true
    var isSyncing = false
    var lastSyncAt: Date?
    var lastSyncError: String?
    var updatedAt = Date()
    var urgentAlerts: [ManagerAlert] = []

    static let empty = ManagerOperationalSnapshot()

    var requiresAttention: Bool {
        !urgentAlerts.isEmpty
    }
}

enum ManagerAlert: Hashable, Codable {
    case noActiveShift
    case deviceOffline
    case pendingSyncOrders(Int)
    case offlineSyncNeedsAttention
    case unreadBroadcasts(Int)
}

@Observable
@MainActor
final class AppState {

    static let shared = AppState()
    private let api = APIService.shared
    private let managerApprovalLogKey = "manager_approval_log"
    private let cachedCurrentUserKey = "cached_current_user"
    private let cachedBroadcastsKey = "cached_broadcasts"
    private let cachedUnreadBroadcastCountKey = "cached_unread_broadcast_count"
    private let saleCompletionSoundEnabledKey = "sale_completion_sound_enabled"

    // MARK: Navigation
    var destination: AppDestination = .login
    var selectedTab: MainTab = .pos

    // MARK: Auth
    var currentUser: CurrentUser? {
        didSet {
            persistCurrentUser()
            exportManagerSnapshot()
        }
    }
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    // MARK: Current Shift
    var currentShift: Shift?
    var shiftLoaded = false
    var unreadBroadcastCount = 0 {
        didSet { UserDefaults.standard.set(unreadBroadcastCount, forKey: cachedUnreadBroadcastCountKey) }
    }
    var latestBroadcasts: [BroadcastItem] = [] {
        didSet { persistBroadcastsCache() }
    }
    var managerApprovalLog: [ManagerApprovalEntry] = []
    var managerSnapshot = ManagerOperationalSnapshot.empty {
        didSet { exportManagerSnapshot() }
    }

    // MARK: Appearance
    var isDark: Bool = UserDefaults.standard.object(forKey: "pos_is_dark") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isDark, forKey: "pos_is_dark")
            AppTheme.isDark = isDark
        }
    }
    var isSaleCompletionSoundEnabled: Bool = UserDefaults.standard.object(forKey: "sale_completion_sound_enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isSaleCompletionSoundEnabled, forKey: saleCompletionSoundEnabledKey)
        }
    }

    // MARK: Toast
    var toast: ToastMessage?

    // MARK: Spotlight deep-link
    var spotlightOrderId: String?

    // MARK: Biometric Lock
    var isBiometricEnabled: Bool = UserDefaults.standard.bool(forKey: "biometric_lock_enabled") {
        didSet { UserDefaults.standard.set(isBiometricEnabled, forKey: "biometric_lock_enabled") }
    }
    var isLocked: Bool = false

    func unlockWithBiometric() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            isLocked = false  // no biometrics enrolled — unlock anyway
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your POS terminal")
            if success { isLocked = false }
        } catch {
            // User cancelled or failed — stay locked
        }
    }

    private init() {
        AppTheme.isDark = isDark
        restoreManagerApprovalLog()
        restoreCachedSessionState()
        // Auto-logout when refresh token is rejected by the server
        NotificationCenter.default.addObserver(
            forName: APIService.sessionExpiredNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.logout()
                self?.toast = ToastMessage(type: .error, text: "Session expired. Please sign in again.")
            }
        }
        // Restore session if token exists
        if api.isAuthenticated {
            destination = .main
            Task { await loadInitialData() }
        }
    }

    // MARK: Login
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let token = try await api.login(email: email, password: password)
            api.accessToken = token.accessToken
            api.refreshToken = token.refreshToken
            api.tenantSlug = token.tenantSlug
            api.cacheAuthenticatedTenant(from: token)
            currentUser = CurrentUser(from: token)
            await loadInitialData()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                destination = .main
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loginWithPIN(email: String, pin: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let token = try await api.loginWithPIN(email: email, pin: pin)
            api.accessToken = token.accessToken
            api.refreshToken = token.refreshToken
            api.tenantSlug = token.tenantSlug
            api.cacheAuthenticatedTenant(from: token)
            currentUser = CurrentUser(from: token)
            await loadInitialData()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                destination = .main
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func logout() {
        api.logout()
        currentUser = nil
        currentShift = nil
        shiftLoaded = false
        unreadBroadcastCount = 0
        latestBroadcasts = []
        managerSnapshot = .empty
        ManagerSnapshotStore.shared.clear()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            destination = .login
        }
    }

    private func restoreCachedSessionState() {
        if let data = UserDefaults.standard.data(forKey: cachedCurrentUserKey),
           let cachedUser = try? JSONDecoder().decode(CurrentUser.self, from: data) {
            currentUser = cachedUser
        }

        if let data = UserDefaults.standard.data(forKey: "cached_current_shift"),
           let cachedShift = try? JSONDecoder().decode(Shift.self, from: data) {
            currentShift = cachedShift
        }

        if let data = UserDefaults.standard.data(forKey: cachedBroadcastsKey),
           let cachedBroadcasts = try? JSONDecoder().decode([BroadcastItem].self, from: data) {
            latestBroadcasts = cachedBroadcasts
        }

        unreadBroadcastCount = UserDefaults.standard.integer(forKey: cachedUnreadBroadcastCountKey)
    }

    private func persistCurrentUser() {
        guard let currentUser else {
            UserDefaults.standard.removeObject(forKey: cachedCurrentUserKey)
            return
        }
        guard let data = try? JSONEncoder().encode(currentUser) else { return }
        UserDefaults.standard.set(data, forKey: cachedCurrentUserKey)
    }

    private func persistBroadcastsCache() {
        guard let data = try? JSONEncoder().encode(latestBroadcasts) else { return }
        UserDefaults.standard.set(data, forKey: cachedBroadcastsKey)
    }

    func recordManagerApproval(action: String, managerName: String, managerRole: String) {
        let entry = ManagerApprovalEntry(
            action: action,
            managerName: managerName,
            managerRole: managerRole,
            approvedAt: ISO8601DateFormatter().string(from: Date())
        )
        managerApprovalLog.insert(entry, at: 0)
        if managerApprovalLog.count > 20 {
            managerApprovalLog = Array(managerApprovalLog.prefix(20))
        }
        persistManagerApprovalLog()
    }

    private func restoreManagerApprovalLog() {
        guard let data = UserDefaults.standard.data(forKey: managerApprovalLogKey),
              let entries = try? JSONDecoder().decode([ManagerApprovalEntry].self, from: data) else {
            managerApprovalLog = []
            return
        }
        managerApprovalLog = entries
    }

    private func persistManagerApprovalLog() {
        guard let data = try? JSONEncoder().encode(managerApprovalLog) else { return }
        UserDefaults.standard.set(data, forKey: managerApprovalLogKey)
    }

    // MARK: Load initial data
    private func loadInitialData() async {
        restoreCachedSessionState()
        async let shiftTask: Void = loadCurrentShift()
        async let broadcastsTask: Void = refreshBroadcasts()
        _ = await (shiftTask, broadcastsTask)
        await refreshManagerSnapshot()
    }

    func refreshBroadcasts() async {
        do {
            let response = try await api.fetchBroadcasts()
            latestBroadcasts = response.items
            unreadBroadcastCount = response.unreadCount
        } catch {
            // Keep the last known state if refresh fails.
        }
        syncManagerSnapshotWithLocalState()
    }

    func loadCurrentShift() async {
        do {
            currentShift = try await api.getCurrentShift()
            // Persist for offline use
            if let shift = currentShift,
               let data = try? JSONEncoder().encode(shift) {
                UserDefaults.standard.set(data, forKey: "cached_current_shift")
            }
        } catch {
            // Offline fallback: load last known shift from cache
            if let data = UserDefaults.standard.data(forKey: "cached_current_shift"),
               let cached = try? JSONDecoder().decode(Shift.self, from: data) {
                currentShift = cached
            } else {
                currentShift = nil
            }
        }
        shiftLoaded = true
        syncManagerSnapshotWithLocalState()
    }

    func refreshManagerSnapshot() async {
        let fetchedOrders = try? await api.fetchOrders()
        updateManagerSnapshot(using: fetchedOrders)
    }

    func syncManagerSnapshotWithLocalState() {
        updateManagerSnapshot(using: nil)
    }

    private func updateManagerSnapshot(using orders: [Order]?) {
        let offlineManager = OfflineManager.shared
        let activeOrders = orders?.filter { ["received", "preparing", "ready"].contains($0.status) }.count
        let paidOrders = orders?.filter { $0.status == "paid" }.count

        var urgentAlerts: [ManagerAlert] = []
        if currentShift == nil {
            urgentAlerts.append(.noActiveShift)
        }
        if !offlineManager.isOnline {
            urgentAlerts.append(.deviceOffline)
        }
        if offlineManager.pendingCount > 0 {
            urgentAlerts.append(.pendingSyncOrders(offlineManager.pendingCount))
        }
        if offlineManager.lastSyncError != nil {
            urgentAlerts.append(.offlineSyncNeedsAttention)
        }
        if unreadBroadcastCount > 0 {
            urgentAlerts.append(.unreadBroadcasts(unreadBroadcastCount))
        }

        managerSnapshot = ManagerOperationalSnapshot(
            hasActiveShift: currentShift != nil,
            activeShiftId: currentShift?.id,
            openOrdersCount: activeOrders ?? managerSnapshot.openOrdersCount,
            paidOrdersCount: paidOrders ?? managerSnapshot.paidOrdersCount,
            offlinePendingCount: offlineManager.pendingCount,
            unreadBroadcastCount: unreadBroadcastCount,
            isOnline: offlineManager.isOnline,
            isSyncing: offlineManager.isSyncing,
            lastSyncAt: offlineManager.lastSyncAt,
            lastSyncError: offlineManager.lastSyncError,
            updatedAt: Date(),
            urgentAlerts: urgentAlerts
        )
    }

    private func exportManagerSnapshot() {
        ManagerSnapshotStore.shared.save(
            snapshot: managerSnapshot,
            currentUser: currentUser,
            tenantSlug: api.tenantSlug
        )
    }

    // MARK: Toast helpers
    func showSuccess(_ msg: String) {
        toast = ToastMessage(type: .success, text: msg)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.toast = nil
        }
    }

    func showError(_ msg: String) {
        toast = ToastMessage(type: .error, text: msg)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.toast = nil
        }
    }
}

// MARK: - Current User
struct CurrentUser: Codable {
    let userId: String
    let nameEn: String
    let nameAr: String
    let role: String
    let tenantId: String?
    let tenantSlug: String?

    init(from token: TokenResponse) {
        userId = token.userId
        nameEn = token.nameEn
        nameAr = token.nameAr
        role = token.role
        tenantId = token.tenantId
        tenantSlug = token.tenantSlug
    }

    var isManager: Bool { role == "manager" || role == "owner" || role == "super_admin" }
    var displayName: String { nameEn }
    var roleDisplayName: String { role.replacingOccurrences(of: "_", with: " ").capitalized }
}

struct ManagerApprovalEntry: Codable, Identifiable {
    let id: UUID
    let action: String
    let managerName: String
    let managerRole: String
    let approvedAt: String

    init(id: UUID = UUID(), action: String, managerName: String, managerRole: String, approvedAt: String) {
        self.id = id
        self.action = action
        self.managerName = managerName
        self.managerRole = managerRole
        self.approvedAt = approvedAt
    }
}

// MARK: - Main Tabs
enum MainTab: String, CaseIterable {
    case pos      = "POS"
    case orders   = "Orders"
    case tables   = "Tables"
    case shift    = "Shift"
    case reports  = "Reports"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .pos:      return "cart.fill"
        case .orders:   return "list.bullet.clipboard.fill"
        case .tables:   return "table.furniture.fill"
        case .shift:    return "clock.badge.fill"
        case .reports:  return "chart.bar.xaxis"
        case .settings: return "gearshape.2.fill"
        }
    }

    var localizedName: String {
        L10n.shared.tabName(self.rawValue)
    }
}

// MARK: - Toast
struct ToastMessage: Identifiable {
    let id = UUID()
    enum ToastType { case success, error, info }
    let type: ToastType
    let text: String

    var color: Color {
        switch type {
        case .success: return AppTheme.success
        case .error:   return AppTheme.danger
        case .info:    return AppTheme.info
        }
    }
    var icon: String {
        switch type {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }
}

// MARK: - Toast Overlay
struct ToastOverlay: View {
    let toast: ToastMessage
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: toast.icon)
                    .foregroundColor(toast.color)
                    .font(.system(size: 20, weight: .semibold))
                Text(toast.text)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AppTheme.card)
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(toast.color.opacity(0.4), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
