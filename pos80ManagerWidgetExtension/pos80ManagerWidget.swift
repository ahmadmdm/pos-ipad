import SwiftUI
import WidgetKit

enum WidgetStrings {
    static var isArabic: Bool {
        Locale.current.identifier.lowercased().hasPrefix("ar")
    }

    static func t(_ en: String, _ ar: String) -> String {
        isArabic ? ar : en
    }
}

enum SharedSnapshotKeys {
    static let appGroupInfoKey = "AmposSharedAppGroup"
    static let payloadKey = "ampos.shared.managerSnapshot"
}

enum WidgetManagerAlert: Hashable, Codable {
    case noActiveShift
    case deviceOffline
    case pendingSyncOrders(Int)
    case offlineSyncNeedsAttention
    case unreadBroadcasts(Int)
}

struct WidgetManagerSnapshot: Codable {
    let hasActiveShift: Bool
    let activeShiftId: String?
    let openOrdersCount: Int
    let paidOrdersCount: Int
    let offlinePendingCount: Int
    let unreadBroadcastCount: Int
    let isOnline: Bool
    let isSyncing: Bool
    let lastSyncAt: Date?
    let lastSyncError: String?
    let updatedAt: Date
    let urgentAlerts: [WidgetManagerAlert]
}

struct WidgetCurrentUser: Codable {
    let userId: String
    let nameEn: String
    let nameAr: String
    let role: String
    let tenantId: String?
    let tenantSlug: String?

    var displayName: String {
        WidgetStrings.isArabic && !nameAr.isEmpty ? nameAr : nameEn
    }
}

struct WidgetSharedManagerSnapshotPayload: Codable {
    let snapshot: WidgetManagerSnapshot
    let currentUser: WidgetCurrentUser?
    let tenantSlug: String?
    let exportedAt: Date
}

struct ManagerWidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSharedManagerSnapshotPayload?
}

struct ManagerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ManagerWidgetEntry {
        ManagerWidgetEntry(date: Date(), payload: samplePayload)
    }

    func getSnapshot(in context: Context, completion: @escaping (ManagerWidgetEntry) -> Void) {
        completion(ManagerWidgetEntry(date: Date(), payload: loadPayload() ?? samplePayload))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ManagerWidgetEntry>) -> Void) {
        let entry = ManagerWidgetEntry(date: Date(), payload: loadPayload())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadPayload() -> WidgetSharedManagerSnapshotPayload? {
        for defaults in defaultsTargets() {
            guard let data = defaults.data(forKey: SharedSnapshotKeys.payloadKey),
                  let payload = try? JSONDecoder().decode(WidgetSharedManagerSnapshotPayload.self, from: data) else {
                continue
            }
            return payload
        }
        return nil
    }

    private func defaultsTargets() -> [UserDefaults] {
        var targets = [UserDefaults.standard]
        if let group = Bundle.main.object(forInfoDictionaryKey: SharedSnapshotKeys.appGroupInfoKey) as? String,
           !group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let sharedDefaults = UserDefaults(suiteName: group) {
            targets.insert(sharedDefaults, at: 0)
        }
        return targets
    }

    private var samplePayload: WidgetSharedManagerSnapshotPayload {
        WidgetSharedManagerSnapshotPayload(
            snapshot: WidgetManagerSnapshot(
                hasActiveShift: true,
                activeShiftId: "SHIFT-42",
                openOrdersCount: 12,
                paidOrdersCount: 34,
                offlinePendingCount: 2,
                unreadBroadcastCount: 1,
                isOnline: true,
                isSyncing: false,
                lastSyncAt: Date().addingTimeInterval(-420),
                lastSyncError: nil,
                updatedAt: Date(),
                urgentAlerts: [.pendingSyncOrders(2), .unreadBroadcasts(1)]
            ),
            currentUser: WidgetCurrentUser(
                userId: "manager-1",
                nameEn: "Floor Manager",
                nameAr: "مدير التشغيل",
                role: "manager",
                tenantId: nil,
                tenantSlug: "demo"
            ),
            tenantSlug: "demo",
            exportedAt: Date()
        )
    }
}

struct pos80ManagerWidgetEntryView: View {
    var entry: ManagerWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let payload = entry.payload {
            content(payload)
        } else {
            emptyState
        }
    }

    private func content(_ payload: WidgetSharedManagerSnapshotPayload) -> some View {
        let snapshot = payload.snapshot

        return ZStack {
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.96, blue: 0.91), Color(red: 0.94, green: 0.86, blue: 0.74)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(WidgetStrings.t("MANAGER SNAPSHOT", "ملخص المدير"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(Color.orange)
                        Text(payload.currentUser?.displayName ?? WidgetStrings.t("Manager", "المدير"))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(statusLine(snapshot))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        statusBadge(snapshot)
                        Text(relativeDate(payload.exportedAt))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    metricCard(WidgetStrings.t("Open Orders", "الطلبات النشطة"), value: "\(snapshot.openOrdersCount)", tint: Color.blue)
                    metricCard(WidgetStrings.t("Pending Sync", "المزامنة المعلقة"), value: "\(snapshot.offlinePendingCount)", tint: snapshot.offlinePendingCount > 0 ? Color.orange : Color.green)
                    metricCard(WidgetStrings.t("Broadcasts", "التنبيهات"), value: "\(snapshot.unreadBroadcastCount)", tint: snapshot.unreadBroadcastCount > 0 ? Color.pink : Color.gray)
                }

                if family == .systemLarge || !snapshot.urgentAlerts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(WidgetStrings.t("Alerts", "التنبيهات"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        if snapshot.urgentAlerts.isEmpty {
                            Text(WidgetStrings.t("No urgent manager alerts.", "لا توجد تنبيهات إدارية عاجلة."))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(snapshot.urgentAlerts.prefix(family == .systemLarge ? 4 : 2)), id: \.self) { alert in
                                HStack(spacing: 6) {
                                    Image(systemName: alertIcon(alert))
                                        .font(.system(size: 10, weight: .bold))
                                    Text(alertTitle(alert))
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(alertColor(alert))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .managerWidgetBackground()
    }

    private var emptyState: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.96, blue: 0.93), Color(red: 0.91, green: 0.88, blue: 0.83)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 10) {
                Text(WidgetStrings.t("Manager Widget", "ودجت الإدارة"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(WidgetStrings.t("Open the POS app to publish the latest manager snapshot.", "افتح تطبيق نقطة البيع لنشر أحدث ملخص للإدارة."))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Label(WidgetStrings.t("Awaiting data", "بانتظار البيانات"), systemImage: "arrow.clockwise.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.orange)
            }
            .padding(16)
        }
        .managerWidgetBackground()
    }

    private func metricCard(_ title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusBadge(_ snapshot: WidgetManagerSnapshot) -> some View {
        let title = snapshot.isOnline ? WidgetStrings.t("Online", "متصل") : WidgetStrings.t("Offline", "غير متصل")
        let tint = snapshot.isOnline ? Color.green : Color.orange
        return Text(title)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }

    private func statusLine(_ snapshot: WidgetManagerSnapshot) -> String {
        if let error = snapshot.lastSyncError, !error.isEmpty {
            return error
        }
        if !snapshot.hasActiveShift {
            return WidgetStrings.t("No active shift is open.", "لا توجد وردية نشطة مفتوحة.")
        }
        if snapshot.offlinePendingCount > 0 {
            return WidgetStrings.t("Offline queue needs review.", "قائمة الأوفلاين تحتاج مراجعة.")
        }
        return WidgetStrings.t("Operations are tracking normally.", "العمليات تسير بشكل طبيعي.")
    }

    private func alertTitle(_ alert: WidgetManagerAlert) -> String {
        switch alert {
        case .noActiveShift:
            return WidgetStrings.t("No active shift", "لا توجد وردية نشطة")
        case .deviceOffline:
            return WidgetStrings.t("Device offline", "الجهاز غير متصل")
        case .pendingSyncOrders(let count):
            return WidgetStrings.t("\(count) orders pending sync", "\(count) طلبات بانتظار المزامنة")
        case .offlineSyncNeedsAttention:
            return WidgetStrings.t("Offline sync needs attention", "مزامنة الأوفلاين تحتاج متابعة")
        case .unreadBroadcasts(let count):
            return WidgetStrings.t("\(count) unread broadcasts", "\(count) تنبيهات غير مقروءة")
        }
    }

    private func alertIcon(_ alert: WidgetManagerAlert) -> String {
        switch alert {
        case .noActiveShift:
            return "clock.badge.exclamationmark"
        case .deviceOffline, .pendingSyncOrders, .offlineSyncNeedsAttention:
            return "arrow.triangle.2.circlepath"
        case .unreadBroadcasts:
            return "megaphone.fill"
        }
    }

    private func alertColor(_ alert: WidgetManagerAlert) -> Color {
        switch alert {
        case .noActiveShift:
            return .blue
        case .deviceOffline, .pendingSyncOrders, .offlineSyncNeedsAttention:
            return .orange
        case .unreadBroadcasts:
            return .pink
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct pos80ManagerWidget: Widget {
    let kind: String = "pos80ManagerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ManagerWidgetProvider()) { entry in
            pos80ManagerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetStrings.t("Manager Snapshot", "ملخص المدير"))
        .description(WidgetStrings.t("Monitor shift health, offline sync, and manager alerts.", "راقب الوردية والمزامنة والتنبيهات الإدارية."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct pos80ManagerWidgetBundle: WidgetBundle {
    var body: some Widget {
        pos80ManagerWidget()
    }
}

private extension View {
    @ViewBuilder
    func managerWidgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            self.background(Color.clear)
        }
    }
}
