import ActivityKit
import Foundation

struct ShoppingActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var completed: Int
        var total: Int
    }
    var listName: String
    var startedAt: Date
}

import AppIntents

struct FinishShoppingSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Finish Pantry shopping session"
    func perform() async throws -> some IntentResult {
        for activity in Activity<ShoppingActivity>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
        return .result()
    }
}
