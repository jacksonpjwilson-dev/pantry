import SwiftUI
import WatchConnectivity

@MainActor final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var shopping: [[String: String]] = []
    @Published var low: [[String: String]] = []
    @Published var count = 0
    @Published var updated: Date?
    private var account = ""
    override init() {
        super.init()
        if let saved = UserDefaults.standard.dictionary(forKey: "snapshot") { apply(saved) }
        if WCSession.isSupported() { WCSession.default.delegate = self; WCSession.default.activate() }
    }
    func apply(_ snapshot: [String: Any]) {
        shopping = snapshot["shopping"] as? [[String: String]] ?? []; low = snapshot["low"] as? [[String: String]] ?? []; count = snapshot["count"] as? Int ?? 0
        updated = (snapshot["updated"] as? Double).map { Date(timeIntervalSince1970: $0) }; account = snapshot["account"] as? String ?? ""
        UserDefaults.standard.set(snapshot, forKey: "snapshot")
    }
    func purchase(_ id: String) { WCSession.default.transferUserInfo(["purchase": id, "account": account]) }
    func adjust(_ id: String, delta: Int) { WCSession.default.transferUserInfo(["item": id, "delta": String(delta), "operation": "watch_" + UUID().uuidString, "account": account]) }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { Task { @MainActor in if !session.receivedApplicationContext.isEmpty { self.apply(session.receivedApplicationContext) } } }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { Task { @MainActor in self.apply(applicationContext) } }
}
@main struct PantryWatchApp: App {
    @StateObject var store = WatchStore()
    var body: some Scene { WindowGroup {
        NavigationStack { List {
            Section("Pantry · \(store.count) foods") {
                if let updated = store.updated { Text("Phone snapshot \(updated.formatted())").font(.caption) } else { Text("Open Pantry on iPhone to connect") }
                Text("Actions queue to iPhone; open Pantry there to resolve any conflicts.").font(.caption)
            }
            Section("Shopping") { ForEach(store.shopping, id: \.self) { row in Button(row["name"] ?? "Food") { if let id = row["id"] { store.purchase(id) } } } }
            Section("Low stock") { ForEach(store.low, id: \.self) { row in
                NavigationLink(row["name"] ?? "Food") { VStack { Text("\(row["qty"] ?? "0") \(row["unit"] ?? "")"); Button("Add one unit") { if let id = row["id"] { store.adjust(id, delta: 1) } }; Button("Use one unit") { if let id = row["id"] { store.adjust(id, delta: -1) } } } }
            } }
        }.navigationTitle("Pantry") }
    } }
}
