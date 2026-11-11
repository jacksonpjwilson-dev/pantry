import AppIntents
import Foundation

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
    static var title: LocalizedStringResource = "Show low-stock food in Pantry"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult & OpensIntent { .result(opensIntent: OpenURLIntent(URL(string: "pantry://inventory?filter=low")!)) }
}
struct PantryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenPantryIntent(), phrases: ["Open \(.applicationName)"], shortTitle: "Open Pantry", systemImageName: "cabinet")
        AppShortcut(intent: ShowShoppingIntent(), phrases: ["Show my shopping list in \(.applicationName)"], shortTitle: "Shopping list", systemImageName: "cart")
        AppShortcut(intent: AddShoppingIntent(), phrases: ["Add a shopping item in \(.applicationName)"], shortTitle: "Add shopping item", systemImageName: "cart.badge.plus")
        AppShortcut(intent: MarkPurchasedIntent(), phrases: ["Mark purchased in \(.applicationName)"], shortTitle: "Mark purchased", systemImageName: "checkmark.circle")
        AppShortcut(intent: AddInventoryIntent(), phrases: ["Add stock in \(.applicationName)"], shortTitle: "Add stock", systemImageName: "plus.circle")
        AppShortcut(intent: ShowExpiryIntent(), phrases: ["Show upcoming dates in \(.applicationName)"], shortTitle: "Upcoming dates", systemImageName: "calendar")
        AppShortcut(intent: OpenScannerIntent(), phrases: ["Scan a barcode in \(.applicationName)"], shortTitle: "Scan barcode", systemImageName: "barcode.viewfinder")
        AppShortcut(intent: ShowLowStockIntent(), phrases: ["Show inventory in \(.applicationName)"], shortTitle: "Inventory", systemImageName: "leaf")
    }
}

private func pantryURL(_ host: String, _ query: [String: String] = [:]) -> URL {
    var components = URLComponents(); components.scheme = "pantry"; components.host = host
    components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
    return components.url!
}
struct AddShoppingIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a Pantry shopping item"
    static var openAppWhenRun = true
    @Parameter(title: "Food") var name: String
    @Parameter(title: "Quantity", default: 1) var quantity: Double
    func perform() async throws -> some IntentResult & OpensIntent {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, quantity.isFinite, quantity > 0 else { throw IntentValidation.invalid }
        return .result(opensIntent: OpenURLIntent(pantryURL("action", ["kind":"shopping", "name":name, "quantity":String(quantity)])))
    }
}
struct MarkPurchasedIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark a Pantry shopping item purchased"
    static var openAppWhenRun = true
    @Parameter(title: "Shopping item name") var name: String
    func perform() async throws -> some IntentResult & OpensIntent {
        guard !name.isEmpty else { throw IntentValidation.invalid }
        return .result(opensIntent: OpenURLIntent(pantryURL("action", ["kind":"purchase", "name":name])))
    }
}
struct AddInventoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add inventory quantity in Pantry"
    static var openAppWhenRun = true
    @Parameter(title: "Food name") var name: String
    @Parameter(title: "Quantity in inventory units", default: 1) var quantity: Double
    func perform() async throws -> some IntentResult & OpensIntent {
        guard !name.isEmpty, quantity.isFinite, quantity > 0 else { throw IntentValidation.invalid }
        return .result(opensIntent: OpenURLIntent(pantryURL("action", ["kind":"inventory", "name":name, "quantity":String(quantity)])))
    }
}
struct ShowExpiryIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Pantry foods with upcoming dates"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult & OpensIntent { .result(opensIntent: OpenURLIntent(pantryURL("inventory", ["filter":"expiry"]))) }
}
struct OpenScannerIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Pantry barcode scanner"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult & OpensIntent { .result(opensIntent: OpenURLIntent(pantryURL("inventory", ["scan":"true"]))) }
}
private enum IntentValidation: LocalizedError {
    case invalid
    var errorDescription: String? { "Enter a food name and a positive finite quantity." }
}
