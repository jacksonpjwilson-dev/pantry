import Foundation
import UserNotifications

@MainActor enum ReminderService {
    static func configure(items: [InventoryItem]) async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else { return }
        let defaults = UserDefaults.standard
        var requests: [UNNotificationRequest] = []
        for item in items {
            let key = "low-" + item.id
            if item.status == "ok" { defaults.removeObject(forKey: key) }
            else if !defaults.bool(forKey: key) {
                let content = UNMutableNotificationContent(); content.title = "Pantry is running low"; content.body = "Check your low-stock foods in Pantry."; content.sound = .default
                requests.append(UNNotificationRequest(identifier: key, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)))
            }
            if let date = item.expirationDate, item.qty > 0, let reminder = Calendar.current.date(byAdding: .day, value: -3, to: date), reminder > Date() {
                let content = UNMutableNotificationContent(); content.title = "A recorded food date is approaching"; content.body = "Check recorded dates in Pantry. Dates alone do not determine food safety."
                requests.append(UNNotificationRequest(identifier: "expiry-" + item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day], from: reminder), repeats: false)))
            }
        }
        // Reserve room under iOS's pending notification limit; remove only our expiry reminders.
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("expiry-") }.map(\.identifier))
        for request in requests.prefix(50) { try await center.add(request); if request.identifier.hasPrefix("low-") { defaults.set(true, forKey: request.identifier) } }
    }
}
