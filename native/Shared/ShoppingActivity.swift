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
