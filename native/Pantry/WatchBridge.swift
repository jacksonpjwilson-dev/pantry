import WatchConnectivity
import Foundation

@MainActor final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    weak var store: PantryStore?
    override init() { super.init(); if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() } }
    func publish(state: DeviceState) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated, WCSession.default.isPaired else { return }
        let shopping = state.shopping.filter { !$0.purchased }.map { ["id": $0.id, "name": $0.name] }
        let low = state.items.filter { $0.status != "ok" }.map { ["id": $0.id, "name": $0.name, "qty": NSDecimalNumber(decimal: $0.qty).stringValue, "unit": $0.unit] }
        do { try WCSession.default.updateApplicationContext(["account": store?.user?.uid ?? "device", "shopping": shopping, "low": low, "count": state.items.count, "updated": Date().timeIntervalSince1970]) }
        catch { store?.error = "Watch snapshot could not be delivered: \(error.localizedDescription)" }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            guard let store else { return }
            // Commands bind to the phone account's snapshot generation and never switch accounts.
            guard let account = userInfo["account"] as? String, account == (store.user?.uid ?? "device") else { store.error = "A Watch action belongs to a different account. Open Pantry on Watch to refresh."; return }
            await store.perform {
                if let purchase = userInfo["purchase"] as? String { try await store.purchase(purchase, addInventory: false) }
                if let item = userInfo["item"] as? String, let delta = userInfo["delta"] as? String, let amount = Decimal(string: delta), let id = userInfo["operation"] as? String { try await store.adjust(Adjustment(id: id, itemId: item, delta: amount, reason: "manual")) }
            }
        }
    }
}
