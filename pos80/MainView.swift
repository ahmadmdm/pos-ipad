// MainView.swift — App shell with sidebar navigation
import SwiftUI
import TipKit

struct MainView: View {
    @Environment(AppState.self) var appState
    @State private var posVM = POSViewModel()
    private let offlineManager = OfflineManager.shared
    private let l10n = L10n.shared
    @State private var showOfflineQueue = false

    private var showsManagerConsole: Bool {
        appState.currentUser?.isManager ?? false
    }

    var body: some View {
        // No GeometryReader — SwiftUI constrains views within the safe area by default.
        // The HStack fills the safe-area-bounded space from WindowGroup.
        // .background { .ignoresSafeArea() } extends ONLY the decoration behind the status bar.
        HStack(spacing: 0) {
            sidebar

            VStack(spacing: 0) {
                if showsManagerConsole {
                    managerConsole()
                }

                ZStack {
                    switch appState.selectedTab {
                    case .pos:      POSView().environment(posVM)
                    case .orders:   OrdersView()
                    case .tables:   TablesView().environment(posVM)
                    case .shift:    ShiftView()
                    case .reports:  ReportsView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.bg, Color(hex: "FBF5EC"), Color(hex: "EFDCC7")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)

                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 420, height: 420)
                    .blur(radius: 70)
                    .offset(x: -340, y: -220)

                Circle()
                    .fill(AppTheme.info.opacity(0.06))
                    .frame(width: 360, height: 360)
                    .blur(radius: 80)
                    .offset(x: 360, y: 260)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            if appState.unreadBroadcastCount > 0 && appState.selectedTab != .settings {
                HStack(spacing: 12) {
                    Image(systemName: "megaphone.fill")
                        .foregroundColor(AppTheme.warning)
                    Text(l10n.unreadBroadcasts(appState.unreadBroadcastCount))
                        .font(AppTheme.caption(13))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Button(l10n.viewBroadcasts) {
                        appState.selectedTab = .settings
                    }
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.warning)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r12)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                    .strokeBorder(AppTheme.warning.opacity(0.25), lineWidth: 1))
                .shadow(color: AppTheme.shadow, radius: 18, y: 8)
                .padding(.top, 20)
                .padding(.horizontal, 96)
            }
        }
        .overlay {
            if let toast = appState.toast {
                VStack {
                    ToastOverlay(toast: toast)
                        .padding(.horizontal, 80)
                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: appState.toast?.id)
            }
        }
        .task {
            await posVM.loadMenu()
            await posVM.loadTables()
            await appState.refreshBroadcasts()
            ExternalDisplayManager.shared.start(posVM: posVM)
        }
        .sheet(isPresented: $showOfflineQueue) {
            OfflineQueueSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private func managerConsole() -> some View {
        let snapshot = appState.managerSnapshot

        return HStack(spacing: 0) {
            // ── Brand + status ──────────────────────────────────────────────
            HStack(spacing: 8) {
                Circle()
                    .fill(snapshot.urgentAlerts.isEmpty ? AppTheme.success : AppTheme.warning)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l10n.managerConsoleLabel)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.8)
                        .foregroundColor(AppTheme.accent)
                    Text(snapshotSubtitle(for: snapshot))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 20)
            .frame(minWidth: 148, alignment: .leading)

            // Separator
            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 28)
                .padding(.horizontal, 12)

            // ── Live stats ─────────────────────────────────────────────────
            HStack(spacing: 6) {
                consoleStat(
                    value: snapshot.hasActiveShift ? l10n.shiftOpenStatus : l10n.shiftClosedStatus,
                    icon: snapshot.hasActiveShift ? "checkmark.circle.fill" : "clock.badge.exclamationmark.fill",
                    tint: snapshot.hasActiveShift ? AppTheme.success : AppTheme.warning
                ) { appState.selectedTab = .shift }

                consoleStat(
                    value: "\(snapshot.openOrdersCount)",
                    icon: "list.bullet.rectangle.portrait.fill",
                    tint: snapshot.openOrdersCount > 0 ? AppTheme.info : AppTheme.textSecondary
                ) { appState.selectedTab = .orders }

                consoleStat(
                    value: "\(snapshot.offlinePendingCount)",
                    icon: snapshot.isOnline ? "arrow.triangle.2.circlepath.circle.fill" : "wifi.slash",
                    tint: (snapshot.offlinePendingCount > 0 || snapshot.lastSyncError != nil) ? AppTheme.warning : AppTheme.success
                ) { showOfflineQueue = true }

                consoleStat(
                    value: "\(snapshot.unreadBroadcastCount)",
                    icon: "megaphone.fill",
                    tint: snapshot.unreadBroadcastCount > 0 ? AppTheme.warning : AppTheme.textSecondary
                ) { appState.selectedTab = .settings }
            }

            Spacer(minLength: 8)

            // Separator
            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1, height: 28)
                .padding(.horizontal, 12)

            // ── Quick-nav (icon only) ───────────────────────────────────────
            HStack(spacing: 4) {
                consoleNavBtn(icon: "list.bullet.clipboard.fill", tab: .orders, tint: AppTheme.info)
                consoleNavBtn(icon: "chart.bar.xaxis",            tab: .reports, tint: AppTheme.accent)
                consoleNavBtn(icon: "clock.badge.fill",           tab: .shift,
                              tint: snapshot.hasActiveShift ? AppTheme.success : AppTheme.warning)
                consoleNavBtn(icon: "gearshape.2.fill",           tab: .settings, tint: AppTheme.textSecondary)
            }
            .padding(.trailing, 16)
        }
        .frame(height: 52)
        .background(AppTheme.surface.opacity(0.98))
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    private func snapshotSubtitle(for snapshot: ManagerOperationalSnapshot) -> String {
        if let error = snapshot.lastSyncError, !error.isEmpty {
            return error
        }
        if !snapshot.isOnline {
            return l10n.deviceOfflineMonitorQueue
        }
        if !snapshot.hasActiveShift {
            return l10n.noActiveShiftSummary
        }
        if snapshot.openOrdersCount > 0 {
            return l10n.activeOrdersNeedAttention(snapshot.openOrdersCount)
        }
        return l10n.managerOverviewReady
    }

    private func relativeSnapshotTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: l10n.language.rawValue)
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Console Helpers
    private func consoleStat(value: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(tint)
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func consoleNavBtn(icon: String, tab: MainTab, tint: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appState.selectedTab = tab
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(appState.selectedTab == tab ? tint : AppTheme.textMuted)
                .frame(width: 34, height: 34)
                .background(appState.selectedTab == tab ? tint.opacity(0.12) : Color.clear)
                .cornerRadius(9)
        }
        .buttonStyle(.plain)
    }

    private func managerAlertPill(_ alert: ManagerAlert) -> some View {
        Button {
            routeAlert(alert)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: alertIcon(for: alert))
                    .font(.system(size: 11, weight: .semibold))
                Text(alertTitle(alert))
                    .font(AppTheme.caption(11))
                    .lineLimit(1)
            }
            .foregroundColor(alertColor(for: alert))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(alertColor(for: alert).opacity(0.12))
            .cornerRadius(999)
            .overlay(
                Capsule().strokeBorder(alertColor(for: alert).opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func alertTitle(_ alert: ManagerAlert) -> String {
        switch alert {
        case .noActiveShift:
            return l10n.noActiveShiftAlert
        case .deviceOffline:
            return l10n.deviceOfflineAlert
        case .pendingSyncOrders(let count):
            return l10n.pendingSyncOrdersAlert(count)
        case .offlineSyncNeedsAttention:
            return l10n.offlineSyncNeedsAttentionAlert
        case .unreadBroadcasts(let count):
            return l10n.unreadBroadcastsAlert(count)
        }
    }

    private func alertColor(for alert: ManagerAlert) -> Color {
        switch alert {
        case .deviceOffline, .pendingSyncOrders, .offlineSyncNeedsAttention:
            return AppTheme.warning
        case .noActiveShift:
            return AppTheme.info
        case .unreadBroadcasts:
            return AppTheme.accent
        }
    }

    private func alertIcon(for alert: ManagerAlert) -> String {
        switch alert {
        case .deviceOffline, .pendingSyncOrders, .offlineSyncNeedsAttention:
            return "arrow.triangle.2.circlepath"
        case .noActiveShift:
            return "clock.badge.exclamationmark"
        case .unreadBroadcasts:
            return "megaphone.fill"
        }
    }

    private func routeAlert(_ alert: ManagerAlert) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            switch alert {
            case .noActiveShift:
                appState.selectedTab = .shift
            case .unreadBroadcasts:
                appState.selectedTab = .settings
            case .deviceOffline, .pendingSyncOrders, .offlineSyncNeedsAttention:
                showOfflineQueue = true
            }
        }
    }

    private func relativeDateFormatter() -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: l10n.language.rawValue)
        return formatter
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Logo
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.accentGrad)
                        .frame(width: 52, height: 52)
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("AMPOS")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [AppTheme.textPrimary, AppTheme.accent],
                        startPoint: .leading, endPoint: .trailing))

                Text("service")
                    .font(AppTheme.caption(10))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Shift badge
            if let shift = appState.currentShift {
                VStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 8, height: 8)
                    Text(l10n.shift_word)
                        .font(AppTheme.caption(10))
                        .foregroundColor(AppTheme.success)
                    Text("#\(String(shift.id.prefix(6)))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r16)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.r16)
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                )
                .padding(.bottom, 12)
            } else {
                Button { appState.selectedTab = .shift } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.warning)
                            .frame(width: 8, height: 8)
                        Text(l10n.noShift)
                            .font(AppTheme.caption(10))
                            .foregroundColor(AppTheme.warning)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(AppTheme.card)
                    .cornerRadius(AppTheme.r16)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.r16)
                            .strokeBorder(AppTheme.border, lineWidth: 1)
                    )
                }
                .padding(.bottom, 12)
            }

            Divider().background(AppTheme.border).padding(.horizontal, 12)
                .padding(.bottom, 16)

            // Offline / Sync indicator
            if !offlineManager.isOnline || offlineManager.pendingCount > 0 {
                Button {
                    showOfflineQueue = true
                } label: {
                    VStack(spacing: 4) {
                        if !offlineManager.isOnline {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.danger)
                            Text(l10n.offline)
                                .font(AppTheme.caption(10))
                                .foregroundColor(AppTheme.danger)
                        }
                        if offlineManager.pendingCount > 0 {
                            HStack(spacing: 3) {
                                if offlineManager.isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .tint(AppTheme.warning)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 10))
                                        .foregroundColor(AppTheme.warning)
                                }
                                Text("\(offlineManager.pendingCount)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.warning)
                            }
                            Text(l10n.pending)
                                .font(AppTheme.caption(9))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    .padding(.bottom, 8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background(AppTheme.card)
                    .cornerRadius(AppTheme.r16)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.r16)
                            .strokeBorder(AppTheme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            // Navigation items
            VStack(spacing: 4) {
                ForEach(Array(MainTab.allCases.enumerated()), id: \.element) { index, tab in
                    SidebarItem(
                        tab: tab,
                        isSelected: appState.selectedTab == tab,
                        badge: tab == .pos && posVM.cartCount > 0
                            ? "\(posVM.cartCount)"
                            : tab == .settings && appState.unreadBroadcastCount > 0
                                ? "\(appState.unreadBroadcastCount)"
                                : nil
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            appState.selectedTab = tab
                        }
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
            }
            .popoverTip(KeyboardShortcutsTip())

            Spacer()

            // Bottom user info
            VStack(spacing: 16) {
                Divider().background(AppTheme.border).padding(.horizontal, 12)

                if let user = appState.currentUser {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accentGrad)
                                .frame(width: 36, height: 36)
                            Text(String(user.nameEn.prefix(1).uppercased()))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(user.displayName.components(separatedBy: " ").first ?? user.displayName)
                            .font(AppTheme.caption(11))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                        Text(user.roleDisplayName)
                            .font(AppTheme.caption(10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                Button {
                    appState.logout()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.danger)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.danger.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 96)
        .background(
            LinearGradient(
                colors: [AppTheme.surface, Color(hex: "F3E6D7")],
                startPoint: .top,
                endPoint: .bottom)
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(width: 1)
        }
    }
}

struct OfflineQueueSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let offlineManager = OfflineManager.shared
    private let l10n = L10n.shared
    @State private var queueItems: [OfflineOrder] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    statusCard(
                        title: l10n.pendingSyncQueue,
                        value: "\(queueItems.count)",
                        color: AppTheme.warning
                    )
                    statusCard(
                        title: l10n.lastSync,
                        value: lastSyncLabel,
                        color: offlineManager.lastSyncError == nil ? AppTheme.success : AppTheme.danger
                    )
                }

                if queueItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.textMuted)
                        Text(l10n.noPendingOrders)
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(queueItems.filter { !$0.synced }) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.paymentMethod.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(AppTheme.headline(14))
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                        Text(relativeDate(item.createdAt))
                                            .font(AppTheme.caption(11))
                                            .foregroundColor(AppTheme.textMuted)
                                    }
                                    Text("#\(item.localId.prefix(8))")
                                        .font(AppTheme.mono(12))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text("\(item.orderCreate.items.count) items")
                                        .font(AppTheme.caption(12))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.card)
                                .cornerRadius(AppTheme.r12)
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                                    .strokeBorder(AppTheme.border, lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(AppTheme.bg)
            .navigationTitle(l10n.pendingSyncQueue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.close) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.syncNow) {
                        Task {
                            await offlineManager.retrySyncNow()
                            refresh()
                        }
                    }
                    .disabled(offlineManager.isSyncing || queueItems.filter { !$0.synced }.isEmpty)
                }
            }
            .task { refresh() }
        }
    }

    private var lastSyncLabel: String {
        if offlineManager.isSyncing { return l10n.loading }
        if offlineManager.lastSyncError != nil { return l10n.syncFailed }
        guard let date = offlineManager.lastSyncAt else { return "-" }
        return relativeDateFormatter().localizedString(for: date, relativeTo: Date())
    }

    private func refresh() {
        queueItems = offlineManager.queueSnapshot
    }

    private func relativeDate(_ value: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: value) else { return value }
        return relativeDateFormatter().localizedString(for: date, relativeTo: Date())
    }

    private func relativeDateFormatter() -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: l10n.language.rawValue)
        return formatter
    }

    private func statusCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.caption(11))
                .foregroundColor(AppTheme.textMuted)
            Text(value)
                .font(AppTheme.headline(14))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.1))
        .cornerRadius(AppTheme.r12)
    }
}

// MARK: - Sidebar Item
struct SidebarItem: View {
    let tab: MainTab
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 5) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(isSelected ? AppTheme.accentGradH : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)

                    Text(tab.localizedName)
                        .font(AppTheme.caption(10))
                        .foregroundColor(isSelected ? AppTheme.textPrimary : AppTheme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.danger)
                        .cornerRadius(10)
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: 72, height: 72)
            .background(isSelected ? AppTheme.card : Color.clear)
            .cornerRadius(AppTheme.r20)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.r20)
                    .strokeBorder(isSelected ? AppTheme.border : Color.clear, lineWidth: 1)
            )
            .shadow(color: isSelected ? AppTheme.shadow : .clear, radius: 16, y: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

