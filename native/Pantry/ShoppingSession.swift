import ActivityKit
import AppIntents

@MainActor enum ShoppingSession {
    static func start(completed: Int, total: Int) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw InventoryErrorBridge.message("Enable Live Activities for Pantry in iPhone Settings to start a shopping session") }
        guard !Activity<ShoppingActivity>.activities.contains(where: { $0.activityState == .active }) else { return }
        let now = Date()
        _ = try Activity.request(attributes: ShoppingActivity(listName: "Groceries", startedAt: now), content: ActivityContent(state: ShoppingActivity.ContentState(completed: completed, total: total), staleDate: now.addingTimeInterval(4 * 3600)), pushType: nil)
    }
    static func update(completed: Int, total: Int) async {
        for activity in Activity<ShoppingActivity>.activities { await activity.update(ActivityContent(state: ShoppingActivity.ContentState(completed: completed, total: total), staleDate: Date().addingTimeInterval(4 * 3600))) }
    }
    static func finish() async { for activity in Activity<ShoppingActivity>.activities { await activity.end(nil, dismissalPolicy: .immediate) } }
}
