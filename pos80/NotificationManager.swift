// NotificationManager.swift — Local UNUserNotification scheduling helper
import Foundation
import UserNotifications

@MainActor
final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Shift Reminders

    /// Schedule a reminder 30 minutes before the expected shift end.
    /// Call when a shift is opened.
    func scheduleShiftEndReminder(shiftId: String, shiftOpenDate: Date, expectedHours: Double = 8) {
        let reminderDate = shiftOpenDate.addingTimeInterval((expectedHours - 0.5) * 3600)
        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "وقت إغلاق الوردية قريب"
        content.body = "تبقى 30 دقيقة على موعد إغلاق الوردية. تأكد من تسوية الطلبات المعلقة."
        content.sound = .default
        content.categoryIdentifier = "SHIFT_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: reminderDate.timeIntervalSinceNow,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "shift-end-\(shiftId)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelShiftReminders(shiftId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["shift-end-\(shiftId)"])
    }

    // MARK: - Offline Sync Alert

    /// Schedule a reminder if there are unsynced offline orders after a delay.
    /// Cancels any prior alert and schedules a fresh one.
    func scheduleOfflineSyncAlert(pendingCount: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["offline-sync-alert"])
        guard pendingCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "طلبات بانتظار المزامنة"
        content.body = "يوجد \(pendingCount) طلب محفوظ بدون اتصال. تأكد من الاتصال بالإنترنت لإرسالها."
        content.sound = .default

        // Fire after 10 minutes offline
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)
        let request = UNNotificationRequest(
            identifier: "offline-sync-alert",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelOfflineSyncAlert() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["offline-sync-alert"])
    }

    // MARK: - Payment Confirmation (Instant)

    /// Fire an instant local notification confirming a successful payment (useful when app is backgrounded).
    func notifyPaymentSuccess(orderNumber: String, total: Double) {
        let content = UNMutableNotificationContent()
        content.title = "تم استلام الدفع ✓"
        content.body = "الطلب رقم \(orderNumber) — SAR \(String(format: "%.2f", total))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "payment-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
