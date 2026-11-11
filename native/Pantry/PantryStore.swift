import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import WidgetKit

@Model final class LocalSnapshot {
    @Attribute(.unique) var account: String
    var payload: Data
    init(account: String, payload: Data) { self.account = account; self.payload = payload }
}
struct DeviceState: Codable {
    var items: [InventoryItem] = []
    var ledgerData: Data = Data("[]".utf8)
    var metaData: Data = Data("{}".utf8)
    var shopping: [ShoppingItem] = []
    var queue: [Adjustment] = []
    var mutations: [OfflineMutation]? = []
    var pendingShopping: [ShoppingItem]? = []
}
@MainActor final class PantryStore: ObservableObject {
    @Published var state = DeviceState()
    @Published var history: [[String: Any]] = []
    @Published var meta: [String: [String: Any]] = [:]
    @Published var status = "Device only"
    @Published var error: String?
    @Published var busy = false
    @Published var user: User?
    @Published var lastSync: Date?
    @Published var route = "home"
    private var context: ModelContext?
    private var listener: AuthStateDidChangeListenerHandle?
    private var account = "device"
    private var cloud: Firestore? { FirebaseApp.app() == nil ? nil : Firestore.firestore() }
    var configured: Bool { FirebaseApp.app() != nil }
    var inbox: [String: [String: Any]] { meta["inbox"]?.compactMapValues { $0 as? [String: Any] } ?? [:] }
    var low: [InventoryItem] { state.items.filter { $0.status != "ok" } }
    var expiring: [InventoryItem] { state.items.filter { Expiry.upcoming($0, now: Date(), days: 7) } }
    func start(context: ModelContext) {
        guard self.context == nil else { return }; self.context = context
        WatchBridge.shared.store = self
        loadLocal()
        if configured {
            listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor in
                    guard let self else { return }
                    self.user = user; self.account = user?.uid ?? "device"
                    self.state = DeviceState(); self.history = []; self.meta = [:]; self.lastSync = nil
                    self.loadLocal(); self.status = user == nil ? "Device only" : "Pending synchronization"
                    if user != nil { await self.refresh() }
                }
            }
        }
    }
    private func snapshot() throws -> LocalSnapshot? {
        guard let context else { return nil }; let key = account
        return try context.fetch(FetchDescriptor<LocalSnapshot>(predicate: #Predicate { $0.account == key })).first
    }
    private func loadLocal() {
        do {
            if let saved = try snapshot() { state = try JSONDecoder().decode(DeviceState.self, from: saved.payload) }
            history = (try JSONSerialization.jsonObject(with: state.ledgerData)) as? [[String: Any]] ?? []
            meta = (try JSONSerialization.jsonObject(with: state.metaData)) as? [String: [String: Any]] ?? [:]
        } catch { self.error = "Local cache could not be opened: \(error.localizedDescription)" }
    }
    func persist() throws {
        guard let context else { return }
        state.ledgerData = try JSONSerialization.data(withJSONObject: history)
        state.metaData = try JSONSerialization.data(withJSONObject: meta)
        let data = try JSONEncoder().encode(state)
        if let saved = try snapshot() { saved.payload = data } else { context.insert(LocalSnapshot(account: account, payload: data)) }
        try context.save()
        publishWidget()
        WatchBridge.shared.publish(state: state)
    }
    func perform(_ action: () async throws -> Void) async { do { try await action() } catch { self.error = error.localizedDescription } }
    private func collection(_ name: String) throws -> CollectionReference {
        guard let uid = user?.uid, let cloud else { throw InventoryErrorBridge.message("Sign in to use cloud storage") }
        return cloud.collection("pantry").document(uid).collection(name)
    }
    private func item(_ id: String, raw: [String: Any]) -> InventoryItem {
        func decimal(_ key: String) -> Decimal? { (raw[key] as? NSNumber).flatMap { Decimal(string: $0.stringValue) } }
        var value = InventoryItem(id: id, name: raw["name"] as? String ?? "Unnamed", qty: decimal("qty") ?? 0, unit: raw["unit"] as? String ?? "count", category: raw["category"] as? String ?? "Other", lowAt: decimal("lowAt"))
        value.barcode = raw["barcode"] as? String; value.brand = raw["brand"] as? String
        value.notes = raw["notes"] as? String; value.location = raw["location"] as? String; value.imageURL = raw["imageURL"] as? String
        value.dateKind = raw["dateKind"] as? String
        value.expirationDate = (raw["expirationDate"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        value.purchaseDate = (raw["purchaseDate"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        value.createdAt = (raw["createdAt"] as? NSNumber)?.doubleValue ?? 0; value.updatedAt = (raw["updatedAt"] as? NSNumber)?.doubleValue ?? 0
        return value
    }
    private func wire(_ it: InventoryItem) -> [String: Any] {
        ["id": it.id, "name": it.name, "qty": NSDecimalNumber(decimal: it.qty), "unit": it.unit, "category": it.category, "lowAt": it.lowAt.map { NSDecimalNumber(decimal: $0) as Any } ?? NSNull(), "barcode": it.barcode as Any? ?? NSNull(), "brand": it.brand as Any? ?? NSNull(), "notes": it.notes as Any? ?? NSNull(), "location": it.location as Any? ?? NSNull(), "imageURL": it.imageURL as Any? ?? NSNull(), "dateKind": it.dateKind as Any? ?? NSNull(), "expirationDate": it.expirationDate.map { $0.timeIntervalSince1970 * 1000 } as Any? ?? NSNull(), "purchaseDate": it.purchaseDate.map { $0.timeIntervalSince1970 * 1000 } as Any? ?? NSNull(), "createdAt": it.createdAt, "updatedAt": Date().timeIntervalSince1970 * 1000, "updatedBy": "manual"]
    }
    func refresh() async {
        guard !busy, user != nil else { return }; busy = true; defer { busy = false }
        status = "Pending synchronization"
        do {
            // Transactions need network. Pending operations remain durably queued until acknowledged.
            for mutation in state.mutations ?? [] {
                let ref = try collection("items").document(mutation.itemID)
                guard let fields = try JSONSerialization.jsonObject(with: mutation.payload) as? [String: Any] else { throw InventoryError.conflict }
                if mutation.create {
                    _ = try await cloud!.runTransaction { tx, pointer in
                        do { if !(try tx.getDocument(ref).exists) { tx.setData(fields, forDocument: ref) }; return nil }
                        catch { pointer?.pointee = error as NSError; return nil }
                    }
                } else { try await ref.setData(fields, merge: true) }
                state.mutations?.removeAll { $0.id == mutation.id }; try persist()
            }
            for row in state.pendingShopping ?? [] {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                let json = String(data: try encoder.encode(row), encoding: .utf8)!
                try await collection("meta").document("nativeShopping").setData([row.id: json], merge: true)
                state.pendingShopping?.removeAll { $0.id == row.id }; try persist()
            }
            for op in state.queue { try await cloudAdjust(op, source: nil, note: "Queued manual operation") }
            state.queue = []; try persist()
            let items = try await collection("items").getDocuments(source: .server)
            let ledger = try await collection("ledger").getDocuments(source: .server)
            let metadata = try await collection("meta").getDocuments(source: .server)
            state.items = items.documents.map { item($0.documentID, raw: $0.data()) }
            history = ledger.documents.map { $0.data().merging(["id": $0.documentID]) { _, new in new } }
            meta = Dictionary(uniqueKeysWithValues: metadata.documents.map { ($0.documentID, $0.data()) })
            if let rows = meta["nativeShopping"] {
                state.shopping = try rows.filter { $0.key != "payload" }.compactMap { _, value in
                    guard let json = value as? String, let data = json.data(using: .utf8) else { return nil }
                    return try JSONDecoder().decode(ShoppingItem.self, from: data)
                }.sorted { $0.name < $1.name }
            }
            status = "Connected · Logbook not checked"; try persist()
        } catch { status = "Stale · offline or access denied"; self.error = error.localizedDescription }
    }
    func save(_ it: InventoryItem) async throws {
        guard !it.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, it.qty >= 0, it.lowAt.map({ $0 >= 0 }) ?? true else { throw InventoryError.invalidQuantity }
        if user != nil {
            // Editing metadata must never overwrite quantity updated concurrently on another device.
            var fields = wire(it); fields.removeValue(forKey: "id"); fields.removeValue(forKey: "qty")
            let creating = !state.items.contains(where: { $0.id == it.id })
            if creating { fields["qty"] = 0 }
            let mutation = OfflineMutation(itemID: it.id, payload: try JSONSerialization.data(withJSONObject: fields), create: creating)
            state.mutations = (state.mutations ?? []) + [mutation]
        }
        if let index = state.items.firstIndex(where: { $0.id == it.id }) { let qty = state.items[index].qty; state.items[index] = it; state.items[index].qty = qty }
        else { var zero = it; zero.qty = 0; state.items.append(zero) }
        try persist()
        if user != nil { await refresh() }
    }
    func delete(_ id: String) async throws {
        guard !state.queue.contains(where: { $0.itemId == id }), !(state.mutations ?? []).contains(where: { $0.itemID == id }) else { throw InventoryErrorBridge.message("Synchronize pending changes before deleting this item") }
        if user != nil { try await collection("items").document(id).delete() }
        state.items.removeAll { $0.id == id }; try persist() // Historical ledger deliberately retained.
    }
    func adjust(_ op: Adjustment) async throws {
        guard !op.delta.isNaN, state.items.contains(where: { $0.id == op.itemId }) else { throw InventoryError.invalidQuantity }
        if user != nil {
            if !state.queue.contains(where: { $0.id == op.id }) { state.queue.append(op); try persist() }
            await refresh() // Offline operations remain queued and survive termination.
        } else { try localAdjust(op, source: nil, note: "") }
    }
    private func localAdjust(_ op: Adjustment, source: [String: Any]?, note: String) throws {
        guard !history.contains(where: { $0["id"] as? String == op.id }) else { return }
        guard let i = state.items.firstIndex(where: { $0.id == op.itemId }) else { throw InventoryError.missingItem }
        let before = state.items[i].qty, result = try op.apply(to: before)
        let it = state.items[i]; state.items[i].qty = result.after
        history.append(entry(op, itemName: it.name, unit: it.unit, before: before, after: result.after, source: source, note: note))
        try persist()
    }
    private func entry(_ op: Adjustment, itemName: String, unit: String, before: Decimal, after: Decimal, source: [String: Any]?, note: String) -> [String: Any] {
        ["id": op.id, "itemId": op.itemId, "itemName": itemName, "unit": unit, "delta": NSDecimalNumber(decimal: after - before), "requestedDelta": NSDecimalNumber(decimal: op.delta), "unfulfilled": NSDecimalNumber(decimal: op.delta - (after - before)), "qtyBefore": NSDecimalNumber(decimal: before), "qtyAfter": NSDecimalNumber(decimal: after), "reason": op.reason, "source": source as Any? ?? NSNull(), "note": note, "ts": Date().timeIntervalSince1970 * 1000, "undone": false]
    }
    private func cloudAdjust(_ op: Adjustment, source: [String: Any]?, note: String) async throws {
        let lr = try collection("ledger").document(op.id), ir = try collection("items").document(op.itemId)
        _ = try await cloud!.runTransaction { tx, pointer in
            do {
                let prior = try tx.getDocument(lr)
                if let priorRow = prior.data() {
                    guard priorRow["itemId"] as? String == op.itemId else { throw InventoryError.conflict }
                    if let key = source?["key"] as? String, let priorSource = priorRow["source"] as? [String: Any], priorSource["key"] as? String != key { throw InventoryError.conflict }
                    return nil
                }
                let snap = try tx.getDocument(ir); guard let raw = snap.data() else { throw InventoryError.missingItem }
                let before = Decimal(string: (raw["qty"] as? NSNumber)?.stringValue ?? "0") ?? 0
                let after = try op.apply(to: before).after
                let row: [String: Any] = ["id": op.id, "itemId": op.itemId, "itemName": raw["name"] ?? "", "unit": raw["unit"] ?? "count", "delta": NSDecimalNumber(decimal: after - before), "requestedDelta": NSDecimalNumber(decimal: op.delta), "unfulfilled": NSDecimalNumber(decimal: op.delta - (after - before)), "qtyBefore": NSDecimalNumber(decimal: before), "qtyAfter": NSDecimalNumber(decimal: after), "reason": op.reason, "source": source as Any? ?? NSNull(), "note": note, "ts": Date().timeIntervalSince1970 * 1000, "undone": false]
                tx.setData(row, forDocument: lr)
                tx.updateData(["qty": NSDecimalNumber(decimal: after), "updatedAt": Date().timeIntervalSince1970 * 1000, "updatedBy": op.reason == "eaten" || op.reason == "correction" ? "auto" : "manual"], forDocument: ir)
                return nil
            } catch { pointer?.pointee = error as NSError; return nil }
        }
    }
    func undo(_ id: String) async throws {
        if user != nil {
            let lr = try collection("ledger").document(id), ur = try collection("ledger").document("u_" + id), items = try collection("items")
            _ = try await cloud!.runTransaction { tx, pointer in
                do {
                    let original = try tx.getDocument(lr), undo = try tx.getDocument(ur)
                    guard let row = original.data(), !undo.exists, row["undone"] as? Bool != true, let itemID = row["itemId"] as? String else { return nil }
                    let ir = items.document(itemID), snap = try tx.getDocument(ir)
                    guard let item = snap.data() else { throw InventoryError.missingItem }
                    let before = Decimal(string: (item["qty"] as? NSNumber)?.stringValue ?? "0") ?? 0
                    let delta = -(Decimal(string: (row["delta"] as? NSNumber)?.stringValue ?? "0") ?? 0)
                    let after = try Adjustment(itemId: itemID, delta: delta, reason: "undo").apply(to: before).after
                    tx.setData(["id": "u_" + id, "itemId": itemID, "itemName": item["name"] ?? "", "unit": item["unit"] ?? "count", "delta": NSDecimalNumber(decimal: after - before), "qtyBefore": NSDecimalNumber(decimal: before), "qtyAfter": NSDecimalNumber(decimal: after), "reason": "undo", "source": ["of": id], "ts": Date().timeIntervalSince1970 * 1000, "undone": false], forDocument: ur)
                    tx.updateData(["undone": true], forDocument: lr); tx.updateData(["qty": NSDecimalNumber(decimal: after), "updatedAt": Date().timeIntervalSince1970 * 1000, "updatedBy": "manual"], forDocument: ir)
                    return nil
                } catch { pointer?.pointee = error as NSError; return nil }
            }
            await refresh()
        } else {
            guard let i = history.firstIndex(where: { $0["id"] as? String == id }), history[i]["undone"] as? Bool != true, let itemID = history[i]["itemId"] as? String else { return }
            let delta = -(Decimal(string: (history[i]["delta"] as? NSNumber)?.stringValue ?? "0") ?? 0)
            try localAdjust(Adjustment(id: "u_" + id, itemId: itemID, delta: delta, reason: "undo"), source: ["of": id], note: "Undo")
            history[i]["undone"] = true; try persist()
        }
    }
    func setMeta(_ name: String, fields: [String: Any]) async throws {
        if user != nil { try await collection("meta").document(name).setData(fields, merge: true) }
        meta[name] = (meta[name] ?? [:]).merging(fields) { _, new in new }; try persist()
    }
    func syncLogbook() async {
        guard !busy else { return }
        guard let uid = user?.uid, let cloud else { status = "Logbook disconnected · sign in required"; return }
        await refresh(); guard !status.hasPrefix("Stale") else { return }
        busy = true; defer { busy = false }
        do {
            let doc = try await cloud.collection("logbookV2").document(uid).getDocument(source: .server)
            guard let raw = doc.data() else { status = "Logbook disconnected · no v2 document"; return }
            let items = Dictionary(uniqueKeysWithValues: state.items.map { ($0.id, wire($0) as Any) })
            let plan = try LegacyLogbookAdapter().plan(document: raw, items: items, ledger: history, meta: meta)
            // Adjustment writes precede inbox removal/checkpoint. A failure leaves retries safe.
            for op in plan.operations where op["t"] as? String == "adjust" {
                guard let id = op["id"] as? String, let itemID = op["itemId"] as? String, let number = op["delta"] as? NSNumber else { throw InventoryErrorBridge.message("Invalid planned adjustment") }
                try await cloudAdjust(Adjustment(id: id, itemId: itemID, delta: Decimal(string: number.stringValue)!, reason: op["reason"] as? String ?? "correction"), source: op["source"] as? [String: Any], note: op["note"] as? String ?? "")
            }
            for op in plan.operations {
                guard let key = op["key"] as? String else { continue }
                if op["t"] as? String == "inbox" { try await setMeta("inbox", fields: [key: op["entry"] ?? [:]]) }
                if op["t"] as? String == "uninbox" {
                    try await collection("meta").document("inbox").setData([key: FieldValue.delete()], merge: true)
                    meta["inbox"]?.removeValue(forKey: key)
                }
            }
            try await setMeta("state", fields: ["lastCheck": Date().timeIntervalSince1970 * 1000])
            lastSync = Date(); status = "Connected · Logbook v2"; try persist()
            busy = false; await refresh(); status = "Connected · Logbook v2"
        } catch { status = "Logbook pending · review required"; self.error = error.localizedDescription }
    }
    func link(fid: String, itemID: String, per: Decimal) async throws {
        guard per > 0, let item = state.items.first(where: { $0.id == itemID }) else { throw InventoryError.verificationRequired }
        try await setMeta("links", fields: [fid: ["itemId": itemID, "mode": "per", "per": NSDecimalNumber(decimal: per), "food": item.name]])
        if user != nil { try await collection("meta").document("ignored").setData([fid: FieldValue.delete()], merge: true) }
        meta["ignored"]?.removeValue(forKey: fid); await syncLogbook()
    }
    func ignore(fid: String) async throws {
        try await setMeta("ignored", fields: [fid: true])
        for (key, source) in inbox where String(describing: source["fid"] ?? "") == fid {
            if user != nil { try await collection("meta").document("inbox").setData([key: FieldValue.delete()], merge: true) }
            meta["inbox"]?.removeValue(forKey: key)
        }; try persist()
    }
    func saveShopping() async throws {
        if user != nil {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            for row in state.shopping {
                let json = String(data: try encoder.encode(row), encoding: .utf8)!
                if meta["nativeShopping"]?[row.id] as? String != json {
                    state.pendingShopping?.removeAll { $0.id == row.id }
                    state.pendingShopping = (state.pendingShopping ?? []) + [row]
                }
            }
        }
        try persist()
        if user != nil { await refresh() }
    }
    func purchase(_ id: String, addInventory: Bool) async throws {
        guard let i = state.shopping.firstIndex(where: { $0.id == id }) else { return }
        let row = state.shopping[i]
        if addInventory, let itemID = row.itemId {
            try await adjust(Adjustment(id: row.purchaseOperationID, itemId: itemID, delta: row.quantity, reason: "bought"))
            // refresh can replace shopping; locate again before committing.
            if let index = state.shopping.firstIndex(where: { $0.id == id }) { state.shopping[index].addedToInventory = true }
        }
        if let index = state.shopping.firstIndex(where: { $0.id == id }) { state.shopping[index].purchased = true }
        try await saveShopping()
        await ShoppingSession.update(completed: state.shopping.filter(\.purchased).count, total: state.shopping.count)
    }
    func email(_ email: String, password: String, create: Bool) async throws {
        guard configured else { throw InventoryErrorBridge.message("Install the iOS GoogleService-Info.plist first") }
        if create { _ = try await Auth.auth().createUser(withEmail: email, password: password) } else { _ = try await Auth.auth().signIn(withEmail: email, password: password) }
    }
    func google() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { throw InventoryErrorBridge.message("Google sign-in needs the registered iOS Firebase client and URL scheme") }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
        guard let token = result.user.idToken?.tokenString else { throw InventoryErrorBridge.message("Missing Google identity token") }
        _ = try await Auth.auth().signIn(with: GoogleAuthProvider.credential(withIDToken: token, accessToken: result.user.accessToken.tokenString))
    }
    func signOut() throws { guard !busy, state.queue.isEmpty, (state.mutations ?? []).isEmpty, (state.pendingShopping ?? []).isEmpty else { throw InventoryErrorBridge.message("Resolve queued operations before signing out") }; try Auth.auth().signOut() }
    func clearDevice() throws {
        guard user == nil else { throw InventoryErrorBridge.message("Sign out before removing device-only data") }
        state = DeviceState(); history = []; meta = [:]; try persist()
    }
    private func publishWidget() {
        // No food names or cloud identifiers in shared lock-screen snapshot.
        guard let defaults = UserDefaults(suiteName: "group.dev.jacksonwilson.pantry") else { return }
        defaults.set(low.count, forKey: "low"); defaults.set(expiring.count, forKey: "expiry"); defaults.set(inbox.count, forKey: "inbox")
        defaults.set(state.shopping.filter { !$0.purchased }.count, forKey: "shopping"); defaults.set(Date(), forKey: "updated")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
