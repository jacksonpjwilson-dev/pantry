import AppIntents
import Foundation
import WidgetKit

struct WidgetPurchaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete a Pantry shopping item"
    static var openAppWhenRun = true
    @Parameter(title: "Shopping ID") var shoppingID: String
    @Parameter(title: "Account scope") var accountTag: String
    init() {}
    init(shoppingID: String, accountTag: String) { self.shoppingID = shoppingID; self.accountTag = accountTag }
    func perform() async throws -> some IntentResult {
        guard let snapshot = WidgetStorage.snapshot(), snapshot.accountTag == accountTag, snapshot.shopping.contains(where: { $0.id == shoppingID }) else { throw WidgetIntentError.stale }
        try WidgetStorage.enqueue(WidgetPurchaseCommand(shoppingID: shoppingID, accountTag: accountTag))
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
private enum WidgetIntentError: LocalizedError { case stale; var errorDescription: String? { "Open Pantry to refresh this shopping list." } }
