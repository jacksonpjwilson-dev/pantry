import Foundation
import UserNotifications

@MainActor enum ReminderService {
    static func allowedDate(_ date: Date, defaults: UserDefaults = .standard, calendar: Calendar = .current) -> Date {
        let start = defaults.object(forKey: "quietStart") as? Int ?? 22, end = defaults.object(forKey: "quietEnd") as? Int ?? 8
        guard start != end else { return date }
        let hour = calendar.component(.hour, from: date)
        let quiet = start < end ? (hour >= start && hour < end) : (hour >= start || hour < end)
        guard quiet else { return date }
        return calendar.nextDate(after: date, matching: DateComponents(hour: end, minute: 0), matchingPolicy: .nextTime) ?? date
    }
    static func configure(items: [InventoryItem], scope: String, shoppingCount: Int = 0) async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else { return }
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "pantry-reminder-scope") != scope {
            let old = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: old.filter { $0.identifier.hasPrefix("pantry-") }.map(\.identifier))
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("pantry-low-") { defaults.removeObject(forKey: key) }
            defaults.set(scope, forKey: "pantry-reminder-scope")
        }
        defaults.set(true, forKey: "remindersEnabled")
        var requests: [UNNotificationRequest] = []
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.identifier.hasPrefix("pantry-expiry-") }.map(\.identifier))
        let notifyLow = defaults.object(forKey: "notifyLow") as? Bool ?? true, notifyExpiry = defaults.object(forKey: "notifyExpiry") as? Bool ?? true
        for item in items {
            let key = "pantry-low-" + item.id
            if item.status == "ok" || !notifyLow { defaults.removeObject(forKey: key); center.removePendingNotificationRequests(withIdentifiers: [key]) }
            else if !defaults.bool(forKey: key) {
                let content = UNMutableNotificationContent(); content.title = "Pantry is running low"; content.body = "Check your low-stock foods in Pantry."; content.sound = .default
                requests.append(UNNotificationRequest(identifier: key, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(2, allowedDate(Date().addingTimeInterval(2)).timeIntervalSinceNow), repeats: false)))
            }
            if notifyExpiry, let date = item.expirationDate, item.qty > 0, let reminder = Calendar.current.date(byAdding: .day, value: -(defaults.object(forKey: "expiryDays") as? Int ?? 3), to: date), reminder > Date() {
                let content = UNMutableNotificationContent(); content.title = "A recorded food date is approaching"; content.body = "Check recorded dates in Pantry. Dates alone do not determine food safety."
                requests.append(UNNotificationRequest(identifier: "pantry-expiry-" + item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: allowedDate(reminder)), repeats: false)))
            }
        }
        let shoppingKey = "pantry-shopping-" + scope
        if shoppingCount == 0 || !defaults.bool(forKey: "notifyShopping") { defaults.removeObject(forKey: shoppingKey); center.removePendingNotificationRequests(withIdentifiers: [shoppingKey]) }
        else if !defaults.bool(forKey: shoppingKey) {
            let content = UNMutableNotificationContent(); content.title = "Your Pantry shopping list is waiting"; content.body = "Open Pantry to review outstanding shopping items."
            try await center.add(UNNotificationRequest(identifier: shoppingKey, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(60, allowedDate(Date().addingTimeInterval(86400)).timeIntervalSinceNow), repeats: false)))
            defaults.set(true, forKey: shoppingKey)
        }
        for request in requests.prefix(50) { try await center.add(request); if request.identifier.hasPrefix("pantry-low-") { defaults.set(true, forKey: request.identifier) } }
    }
    static func reviewNeeded(scope: String, needed: Bool) async throws {
        let defaults = UserDefaults.standard, center = UNUserNotificationCenter.current(), key = "pantry-review-" + scope
        if !needed { defaults.removeObject(forKey: key); center.removePendingNotificationRequests(withIdentifiers: [key]); return }
        guard defaults.bool(forKey: "remindersEnabled"), defaults.bool(forKey: "notifyReview"), !defaults.bool(forKey: key) else { return }
        let content = UNMutableNotificationContent(); content.title = "Pantry synchronization needs review"; content.body = "Open Pantry to review an authentication, connectivity or inventory synchronization issue."
        try await center.add(UNNotificationRequest(identifier: key, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(2, allowedDate(Date().addingTimeInterval(2)).timeIntervalSinceNow), repeats: false)))
        defaults.set(true, forKey: key)
    }
}
