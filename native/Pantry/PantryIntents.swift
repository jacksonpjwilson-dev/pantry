import AppIntents

struct OpenPantryIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Pantry"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { .result() }
}
struct ShowShoppingIntent: AppIntent {
    static var title: LocalizedStringResource = "Show my Pantry shopping list"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult & OpensIntent { .result(opensIntent: OpenURLIntent(URL(string: "pantry://shopping")!)) }
}
struct ShowLowStockIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Pantry inventory"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult & OpensIntent { .result(opensIntent: OpenURLIntent(URL(string: "pantry://inventory")!)) }
}
struct PantryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenPantryIntent(), phrases: ["Open \(.applicationName)"], shortTitle: "Open Pantry", systemImageName: "cabinet")
        AppShortcut(intent: ShowShoppingIntent(), phrases: ["Show my shopping list in \(.applicationName)"], shortTitle: "Shopping list", systemImageName: "cart")
        AppShortcut(intent: ShowLowStockIntent(), phrases: ["Show inventory in \(.applicationName)"], shortTitle: "Inventory", systemImageName: "leaf")
    }
}
