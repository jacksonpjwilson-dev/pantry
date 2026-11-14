import Foundation

struct WidgetSnapshot: Codable {
    struct Row: Codable, Identifiable { var id: String; var title: String; var detail: String }
    var accountTag: String
    var low: [Row]
    var shopping: [Row]
    var expiry: [Row]
    var recentlyEaten: [Row]
    var inboxCount: Int
    var updated: Date
    var syncStatus: String? = nil
    var lastSuccessfulSync: Date? = nil
}
struct WidgetPurchaseCommand: Codable {
    var id = UUID().uuidString
    var shoppingID: String
    var accountTag: String
}
enum WidgetStorage {
    static let group = Bundle.main.object(forInfoDictionaryKey: "PantryAppGroup") as? String ?? "group.dev.jacksonwilson.pantry"
    static var defaults: UserDefaults? { UserDefaults(suiteName: group) }
    static func snapshot() -> WidgetSnapshot? { guard let data = defaults?.data(forKey: "snapshot") else { return nil }; return try? JSONDecoder().decode(WidgetSnapshot.self, from: data) }
    static func directory() throws -> URL {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { throw CocoaError(.fileNoSuchFile) }
        let directory = group.appendingPathComponent("widget-commands", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    static func enqueue(_ command: WidgetPurchaseCommand) throws {
        let file = try directory().appendingPathComponent(command.id + ".json")
        try JSONEncoder().encode(command).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
