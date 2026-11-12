import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import WidgetKit
import CryptoKit

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
    var lowEpisodes: Set<String>? = []
    var originalImportData: Data?
}
@MainActor final class PantryStore: ObservableObject {
    @Published var state = DeviceState()
    @Published var history: [[String: Any]] = []
    @Published var meta: [String: [String: Any]] = [:]
    @Published var status = "Device only"
    @Published var error: String?
    @Published var busy = false
    @Published var user: User?
    @Published var authenticationReady = false
    @Published var cacheWritable = true
    @Published var lastSync: Date?
    @Published var route = "home"
    @Published var intentRequest: IntentRequest?
    @Published var requestedFilter = "all"
    @Published var requestedPage: String?
    @Published var scanRequested = false
    struct IntentRequest: Identifiable { var id = UUID(); var kind: String; var name: String; var quantity: Decimal }
    func open(_ url: URL) {
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ key: String) -> String? { query.first { $0.name == key }?.value }
        if url.host == "action" {
            guard let kind = value("kind"), ["shopping", "purchase", "inventory"].contains(kind), let name = value("name"), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let quantity = Decimal(string: value("quantity") ?? "1"), quantity > 0, !quantity.isNaN else { error = "Invalid Shortcut parameters"; return }
            intentRequest = IntentRequest(kind: kind, name: name, quantity: quantity)
        } else if let host = url.host, ["home", "inventory", "shopping", "inbox", "settings"].contains(host) {
            requestedFilter = ["low", "expiry"].contains(value("filter") ?? "") ? value("filter")! : "all"
            requestedPage = ["recent", "history"].contains(value("view") ?? "") ? value("view") : nil
            scanRequested = value("scan") == "true"; route = host
        }
    }
    func confirmIntent(_ request: IntentRequest) async throws {
        if request.kind == "shopping" { state.shopping.append(ShoppingItem(name: request.name, quantity: request.quantity)); try await saveShopping() }
        if request.kind == "inventory" {
            let matches = state.items.filter { $0.name.caseInsensitiveCompare(request.name) == .orderedSame }
            guard matches.count == 1 else { throw InventoryErrorBridge.message("Choose a unique inventory food name") }
            try await adjust(Adjustment(itemId: matches[0].id, delta: request.quantity, reason: "bought"))
        }
        if request.kind == "purchase" {
            let matches = state.shopping.filter { !$0.purchased && $0.name.caseInsensitiveCompare(request.name) == .orderedSame }
            guard matches.count == 1 else { throw InventoryErrorBridge.message("Choose a unique pending shopping item") }
            try await purchase(matches[0].id, addInventory: false)
        }
    }
    private var context: ModelContext?
    private var listener: AuthStateDidChangeListenerHandle?
    private var reminderTask: Task<Void, Never>?
    var notificationScope: String { accountTag }
    private var activeOperations = 0
    private var account = "device"
    private var accountTag: String { SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined() }
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
                    self.loadLocal(); self.authenticationReady = true; self.status = user == nil ? "Device only" : "Pending synchronization"
                    if user != nil { await self.refresh() }
                    await self.applyWidgetCommands()
                }
            }
        } else { authenticationReady = true }
    }
    private func snapshot(for accountKey: String? = nil) throws -> LocalSnapshot? {
        guard let context else { return nil }; let key = accountKey ?? account
        return try context.fetch(FetchDescriptor<LocalSnapshot>(predicate: #Predicate { $0.account == key })).first
    }
    private func loadLocal() {
        cacheWritable = true
        do {
            if let saved = try snapshot() { state = try JSONDecoder().decode(DeviceState.self, from: saved.payload) }
            history = (try JSONSerialization.jsonObject(with: state.ledgerData)) as? [[String: Any]] ?? []
            meta = (try JSONSerialization.jsonObject(with: state.metaData)) as? [String: [String: Any]] ?? [:]
            publishWidget(); WatchBridge.shared.publish(state: state)
        } catch { cacheWritable = false; self.error = "Local cache could not be opened: \(error.localizedDescription)" }
    }
    func persist() throws {
        guard cacheWritable else { throw InventoryErrorBridge.message("The local cache is unreadable. It has been preserved; edits are disabled until it is recovered or explicitly removed.") }
        guard let context else { return }
        if UserDefaults.standard.bool(forKey: "autoLowShopping") {
            var episodes = state.lowEpisodes ?? []
            for item in state.items {
                if item.status == "ok" { episodes.remove(item.id); continue }
                if !episodes.contains(item.id) {
                    if !state.shopping.contains(where: { $0.itemId == item.id && !$0.purchased }) {
                        let row = ShoppingItem(name: item.name, itemId: item.id, quantity: max(1, (item.lowAt ?? 0) - item.qty))
                        state.shopping.append(row)
                        if user != nil { state.pendingShopping = (state.pendingShopping ?? []) + [row] }
                    }
                    episodes.insert(item.id)
                }
            }
            state.lowEpisodes = episodes
        }
        state.ledgerData = try JSONSerialization.data(withJSONObject: history)
        state.metaData = try JSONSerialization.data(withJSONObject: meta)
        let data = try JSONEncoder().encode(state)
        do {
            if let saved = try snapshot() { saved.payload = data } else { context.insert(LocalSnapshot(account: account, payload: data)) }
            try context.save()
        } catch { context.rollback(); throw error }
        publishWidget()
        WatchBridge.shared.publish(state: state)
        if UserDefaults.standard.bool(forKey: "remindersEnabled") {
            reminderTask?.cancel()
            let items = state.items, scope = accountTag, shoppingCount = state.shopping.filter { !$0.purchased }.count
            reminderTask = Task {
                do { try await Task.sleep(for: .milliseconds(400)); try Task.checkCancellation(); try await ReminderService.configure(items: items, scope: scope, shoppingCount: shoppingCount) }
                catch is CancellationError {} catch { self.error = "Reminders could not be refreshed: \(error.localizedDescription)" }
            }
        }
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
        ["id": it.id, "name": it.name, "qty": NSDecimalNumber(decimal: it.qty), "unit": it.unit, "category": it.category, "lowAt": it.lowAt.map { NSDecimalNumber(decimal: $0) as Any } ?? NSNull(), "barcode": it.barcode as Any? ?? NSNull(), "brand": it.brand as Any? ?? NSNull(), "notes": it.notes as Any? ?? NSNull(), "location": it.location as Any? ?? NSNull(), "imageURL": it.imageURL as Any? ?? NSNull(), "dateKind": it.dateKind as Any? ?? NSNull(), "expirationDate": it.expirationDate.map { $0.timeIntervalSince1970 * 1000 } as Any? ?? NSNull(), "purchaseDate": it.purchaseDate.map { $0.timeIntervalSince1970 * 1000 } as Any? ?? NSNull(), "createdAt": it.createdAt, "updatedAt": it.updatedAt, "updatedBy": "manual"]
    }
    func refresh() async {
        guard !busy, user != nil else { return }; let scope = account; busy = true; defer { busy = false }
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
                } else {
                    _ = try await cloud!.runTransaction { tx, pointer in
                        do { guard try tx.getDocument(ref).exists else { throw InventoryError.missingItem }; tx.updateData(fields, forDocument: ref); return nil }
                        catch { pointer?.pointee = error as NSError; return nil }
                    }
                }
                guard scope == account else { throw InventoryError.conflict }
                state.mutations?.removeAll { $0.id == mutation.id }; try persist()
            }
            for row in state.pendingShopping ?? [] {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                let json = String(data: try encoder.encode(row), encoding: .utf8)!
                try await collection("meta").document("nativeShopping").setData([row.id: json], merge: true)
                guard scope == account else { throw InventoryError.conflict }
                state.pendingShopping?.removeAll { $0.id == row.id }; try persist()
            }
            for op in state.queue { try await cloudAdjust(op, source: nil, note: "Queued manual operation") }
            guard scope == account else { throw InventoryError.conflict }
            state.queue = []; try persist()
            let items = try await collection("items").getDocuments(source: .server)
            let ledger = try await collection("ledger").getDocuments(source: .server)
            let metadata = try await collection("meta").getDocuments(source: .server)
            guard scope == account else { throw InventoryError.conflict }
            state.items = items.documents.map { item($0.documentID, raw: $0.data()) }
            history = ledger.documents.map { $0.data().merging(["id": $0.documentID]) { _, new in new } }
            meta = Dictionary(uniqueKeysWithValues: metadata.documents.map { ($0.documentID, $0.data()) })
            if let last = meta["state"]?["nativeLastSuccessfulSync"] as? Double { lastSync = Date(timeIntervalSince1970: last / 1000) }
            if let rows = meta["nativeShopping"] {
                state.shopping = try rows.filter { $0.key != "payload" }.compactMap { _, value in
                    guard let json = value as? String, let data = json.data(using: .utf8) else { return nil }
                    return try JSONDecoder().decode(ShoppingItem.self, from: data)
                }.sorted { $0.name < $1.name }
            }
            status = "Connected · Logbook not checked"; try persist()
        } catch { if scope == account { status = "Stale · offline or access denied"; self.error = error.localizedDescription; try? await ReminderService.reviewNeeded(scope: accountTag, needed: true) } }
    }
    func save(_ input: InventoryItem) async throws {
        guard !busy else { throw InventoryErrorBridge.message("Wait for synchronization to finish") }
        var it = input; it.updatedAt = Date().timeIntervalSince1970 * 1000
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
        let scope = account; activeOperations += 1; defer { activeOperations -= 1 }
        guard !busy else { throw InventoryErrorBridge.message("Wait for synchronization to finish") }
        guard !state.queue.contains(where: { $0.itemId == id }), !(state.mutations ?? []).contains(where: { $0.itemID == id }) else { throw InventoryErrorBridge.message("Synchronize pending changes before deleting this item") }
        if user != nil { try await collection("items").document(id).delete() }
        guard scope == account else { throw InventoryError.conflict }
        state.items.removeAll { $0.id == id }; try persist() // Historical ledger deliberately retained.
    }
    func adjust(_ op: Adjustment) async throws {
        guard !busy else { throw InventoryErrorBridge.message("Wait for synchronization to finish") }
        guard !op.delta.isNaN, state.items.contains(where: { $0.id == op.itemId }) else { throw InventoryError.invalidQuantity }
        if user != nil {
            if !state.queue.contains(where: { $0.id == op.id }) {
                let previous = state
                do { state.queue.append(op); try persist() } catch { state = previous; throw error }
            }
            await refresh() // Offline operations remain queued and survive termination.
        } else { try localAdjust(op, source: nil, note: "") }
    }
    private func localAdjust(_ op: Adjustment, source: [String: Any]?, note: String) throws {
        guard !history.contains(where: { $0["id"] as? String == op.id }) else { return }
        guard let i = state.items.firstIndex(where: { $0.id == op.itemId }) else { throw InventoryError.missingItem }
        let previous = state, previousHistory = history
        let before = state.items[i].qty, result = try op.apply(to: before)
        let it = state.items[i]; state.items[i].qty = result.after; state.items[i].updatedAt = Date().timeIntervalSince1970 * 1000
        history.append(entry(op, itemName: it.name, unit: it.unit, before: before, after: result.after, source: source, note: note))
        do { try persist() } catch { state = previous; history = previousHistory; throw error }
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
                guard let saved = raw["qty"] as? NSNumber, saved.doubleValue.isFinite, let before = Decimal(string: saved.stringValue), before >= 0 else { throw InventoryError.invalidQuantity }
                let after = try op.apply(to: before).after
                let row: [String: Any] = ["id": op.id, "itemId": op.itemId, "itemName": raw["name"] ?? "", "unit": raw["unit"] ?? "count", "delta": NSDecimalNumber(decimal: after - before), "requestedDelta": NSDecimalNumber(decimal: op.delta), "unfulfilled": NSDecimalNumber(decimal: op.delta - (after - before)), "qtyBefore": NSDecimalNumber(decimal: before), "qtyAfter": NSDecimalNumber(decimal: after), "reason": op.reason, "source": source as Any? ?? NSNull(), "note": note, "ts": Date().timeIntervalSince1970 * 1000, "undone": false]
                tx.setData(row, forDocument: lr)
                tx.updateData(["qty": NSDecimalNumber(decimal: after), "updatedAt": Date().timeIntervalSince1970 * 1000, "updatedBy": op.reason == "eaten" || op.reason == "correction" ? "auto" : "manual"], forDocument: ir)
                return nil
            } catch { pointer?.pointee = error as NSError; return nil }
        }
    }
    func undo(_ id: String) async throws {
        activeOperations += 1; defer { activeOperations -= 1 }
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
        let scope = account; activeOperations += 1; defer { activeOperations -= 1 }
        if user != nil { try await collection("meta").document(name).setData(fields, merge: true) }
        guard scope == account else { throw InventoryError.conflict }
        meta[name] = (meta[name] ?? [:]).merging(fields) { _, new in new }; try persist()
    }
    func syncLogbook() async {
        guard !busy else { return }
        guard let uid = user?.uid, let cloud else { status = "Logbook disconnected · sign in required"; return }
        await refresh(); guard !status.hasPrefix("Stale") else { return }
        busy = true; defer { busy = false }
        do {
            guard meta["nativeMigration"]?["phase"] as? String != "pending" else { throw InventoryErrorBridge.message("Finish or resume the reviewed device migration before synchronizing Logbook") }
            guard let start = meta["state"]?["startDate"] as? String, start.range(of: #"^\d{4}-\d\d-\d\d$"#, options: .regularExpression) != nil else { throw InventoryErrorBridge.message("Choose the first date to count Logbook food in Settings before enabling consumption synchronization") }
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
            try await setMeta("state", fields: ["lastCheck": Date().timeIntervalSince1970 * 1000, "nativeLastSuccessfulSync": Date().timeIntervalSince1970 * 1000])
            lastSync = Date(); status = "Connected · Logbook v2"; try persist()
            busy = false; await refresh(); if !status.hasPrefix("Stale") { status = "Connected · Logbook v2" }; try? await ReminderService.reviewNeeded(scope: accountTag, needed: false)
        } catch { status = "Logbook pending · review required"; self.error = error.localizedDescription; try? await ReminderService.reviewNeeded(scope: accountTag, needed: true) }
    }
    func link(fid: String, itemID: String, per: Decimal, mode: String = "per") async throws {
        let scope = account; activeOperations += 1; defer { activeOperations -= 1 }
        guard per > 0, let item = state.items.first(where: { $0.id == itemID }) else { throw InventoryError.verificationRequired }
        try await setMeta("links", fields: [fid: ["itemId": itemID, "mode": mode == "auto" ? "auto" : "per", "per": NSDecimalNumber(decimal: per), "food": item.name]])
        if user != nil { try await collection("meta").document("ignored").setData([fid: FieldValue.delete()], merge: true) }
        guard scope == account else { throw InventoryError.conflict }
        meta["ignored"]?.removeValue(forKey: fid); await syncLogbook()
    }
    func ignore(fid: String) async throws {
        let scope = account; activeOperations += 1; defer { activeOperations -= 1 }
        try await setMeta("ignored", fields: [fid: true])
        for (key, source) in inbox where String(describing: source["fid"] ?? "") == fid {
            if user != nil { try await collection("meta").document("inbox").setData([key: FieldValue.delete()], merge: true) }
            guard scope == account else { throw InventoryError.conflict }
            meta["inbox"]?.removeValue(forKey: key)
        }; try persist()
    }
    func restoreIgnored(_ fid: String) async throws {
        let scope = account; activeOperations += 1; defer { activeOperations -= 1 }
        if user != nil { try await collection("meta").document("ignored").setData([fid: FieldValue.delete()], merge: true) }
        guard scope == account else { throw InventoryError.conflict }
        meta["ignored"]?.removeValue(forKey: fid); try persist(); await syncLogbook()
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
        guard authenticationReady, !busy else { throw InventoryErrorBridge.message("Wait for account restoration or synchronization") }
        guard configured else { throw InventoryErrorBridge.message("Install the iOS GoogleService-Info.plist first") }
        if create { _ = try await Auth.auth().createUser(withEmail: email, password: password) } else { _ = try await Auth.auth().signIn(withEmail: email, password: password) }
    }
    func google() async throws {
        guard authenticationReady, !busy else { throw InventoryErrorBridge.message("Wait for account restoration or synchronization") }
        guard let clientID = FirebaseApp.app()?.options.clientID,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { throw InventoryErrorBridge.message("Google sign-in needs the registered iOS Firebase client and URL scheme") }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
        guard let token = result.user.idToken?.tokenString else { throw InventoryErrorBridge.message("Missing Google identity token") }
        _ = try await Auth.auth().signIn(with: GoogleAuthProvider.credential(withIDToken: token, accessToken: result.user.accessToken.tokenString))
    }
    func signOut() throws { guard !busy, activeOperations == 0, state.queue.isEmpty, (state.mutations ?? []).isEmpty, (state.pendingShopping ?? []).isEmpty else { throw InventoryErrorBridge.message("Resolve queued operations before signing out") }; try Auth.auth().signOut(); GIDSignIn.sharedInstance.signOut() }
    struct CloudMigrationPreview: Identifiable {
        var id = UUID(); var source: DeviceState; var digest: String
        var history: [[String: Any]]; var metadata: [String: [String: Any]]
    }
    func previewDeviceMigration() throws -> CloudMigrationPreview {
        guard user != nil, let saved = try snapshot(for: "device") else { throw InventoryErrorBridge.message("No device-only pantry is available to import") }
        let source = try JSONDecoder().decode(DeviceState.self, from: saved.payload)
        guard source.queue.isEmpty, (source.mutations ?? []).isEmpty, (source.pendingShopping ?? []).isEmpty else { throw InventoryErrorBridge.message("The source has unresolved queued changes") }
        let ledger = try JSONSerialization.jsonObject(with: source.ledgerData) as? [[String: Any]] ?? []
        let metadata = try JSONSerialization.jsonObject(with: source.metaData) as? [String: [String: Any]] ?? [:]
        let digest = SHA256.hash(data: saved.payload).map { String(format: "%02x", $0) }.joined()
        return CloudMigrationPreview(source: source, digest: digest, history: ledger, metadata: metadata)
    }
    func migrateDevice(_ preview: CloudMigrationPreview) async throws {
        guard user != nil, !busy else { throw InventoryErrorBridge.message("Sign in and wait for synchronization before migrating") }
        busy = true; defer { busy = false }
        let marker = try collection("meta").document("nativeMigration")
        let previous = try await marker.getDocument(source: .server).data()
        if previous?["digest"] as? String == preview.digest, previous?["phase"] as? String == "complete" { return }
        if previous?["digest"] as? String != preview.digest {
            let inventory = try await collection("items").getDocuments(source: .server)
            let ledger = try await collection("ledger").getDocuments(source: .server)
            guard inventory.isEmpty, ledger.isEmpty, previous == nil else { throw InventoryErrorBridge.message("Cloud migration requires an empty pantry or a matching interrupted migration. Nothing was replaced.") }
        }
        _ = try await cloud!.runTransaction { tx, pointer in
            do {
                if let current = try tx.getDocument(marker).data(), current["digest"] as? String != preview.digest { throw InventoryError.conflict }
                tx.setData(["digest": preview.digest, "phase": "pending"], forDocument: marker, merge: true); return nil
            } catch { pointer?.pointee = error as NSError; return nil }
        }
        // Import deduplication history FIRST. Retries never overwrite an existing record.
        for row in preview.history {
            guard let id = row["id"] as? String, !id.contains("/") else { throw InventoryError.conflict }
            try await importMissing(try collection("ledger").document(id), fields: row)
        }
        for item in preview.source.items {
            var fields = wire(item); fields.removeValue(forKey: "id")
            try await importMissing(try collection("items").document(item.id), fields: fields)
        }
        for (name, fields) in preview.metadata where name != "nativeMigration" {
            guard !name.isEmpty, !name.contains("/") else { throw InventoryError.conflict }
            try await importMissingFields(try collection("meta").document(name), fields: fields)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var rows: [String: Any] = [:]
        for row in preview.source.shopping { rows[row.id] = String(data: try encoder.encode(row), encoding: .utf8)! }
        if !rows.isEmpty { try await importMissingFields(try collection("meta").document("nativeShopping"), fields: rows) }
        try await marker.setData(["digest": preview.digest, "phase": "complete", "completedAt": Date().timeIntervalSince1970 * 1000], merge: true)
        busy = false; await refresh() // Device-only source and history remain intact.
    }
    private func importMissing(_ ref: DocumentReference, fields: [String: Any]) async throws {
        _ = try await cloud!.runTransaction { tx, pointer in
            do {
                if let current = try tx.getDocument(ref).data() {
                    guard (current as NSDictionary).isEqual(fields as NSDictionary) else { throw InventoryError.conflict }
                } else { tx.setData(fields, forDocument: ref) }
                return nil
            } catch { pointer?.pointee = error as NSError; return nil }
        }
    }
    private func importMissingFields(_ ref: DocumentReference, fields: [String: Any]) async throws {
        _ = try await cloud!.runTransaction { tx, pointer in
            do {
                let current = try tx.getDocument(ref).data() ?? [:]
                for (key, value) in fields { if let existing = current[key], !(NSDictionary(dictionary: ["v":existing])).isEqual(NSDictionary(dictionary: ["v":value])) { throw InventoryError.conflict } }
                tx.setData(fields, forDocument: ref, merge: true); return nil
            } catch { pointer?.pointee = error as NSError; return nil }
        }
    }
    struct ImportPreview: Identifiable { var id = UUID(); var data: Data; var items: [InventoryItem]; var ledger: [[String: Any]]; var metadata: [String: [String: Any]]; var nativeState: DeviceState? }
    func previewBrowserImport(_ data: Data) throws -> ImportPreview {
        guard user == nil, state.items.isEmpty, history.isEmpty else { throw InventoryErrorBridge.message("Import requires an empty device-only pantry. Existing data will never be replaced.") }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let rawItems = object["items"] as? [String: [String: Any]], let rawLedger = object["ledger"] as? [String: [String: Any]], let metadata = object["meta"] as? [String: [String: Any]] else { throw InventoryErrorBridge.message("Select a complete pantry:local JSON backup with items, ledger and meta. The read-only nightly summary is not a restorable backup.") }
        var items: [InventoryItem] = []
        for (id, fields) in rawItems {
            guard !id.isEmpty, !id.contains("/"), let name = fields["name"] as? String, !name.isEmpty, let qty = fields["qty"] as? NSNumber, qty.doubleValue.isFinite, qty.doubleValue >= 0, let unit = fields["unit"] as? String, Measures.units.contains(unit) else { throw InventoryErrorBridge.message("Import contains an invalid item: \(id)") }
            items.append(item(id, raw: fields))
        }
        let ledger = try rawLedger.map { id, fields -> [String: Any] in
            guard !id.isEmpty, !id.contains("/"), fields["itemId"] is String, let delta = fields["delta"] as? NSNumber, delta.doubleValue.isFinite else { throw InventoryErrorBridge.message("Import contains an invalid ledger record: \(id)") }
            return fields.merging(["id": id]) { _, new in new }
        }
        var nativeState: DeviceState?
        if let json = object["nativeState"] as? String, let payload = json.data(using: .utf8) {
            let decoded = try JSONDecoder().decode(DeviceState.self, from: payload)
            guard decoded.queue.isEmpty, (decoded.mutations ?? []).isEmpty, (decoded.pendingShopping ?? []).isEmpty else { throw InventoryErrorBridge.message("Resolve queued cloud changes before importing a native backup") }
            nativeState = decoded
        }
        return ImportPreview(data: data, items: items, ledger: ledger, metadata: metadata, nativeState: nativeState)
    }
    func importBrowser(_ preview: ImportPreview) throws {
        _ = try previewBrowserImport(preview.data) // Recheck destination at confirmation time.
        let originalState = state, originalHistory = history, originalMeta = meta
        do {
            if let imported = preview.nativeState { state = imported }
            state.items = preview.items; state.originalImportData = preview.data; history = preview.ledger; meta = preview.metadata
            try persist()
        } catch { state = originalState; history = originalHistory; meta = originalMeta; throw error }
    }
    func exportBackup() throws -> URL {
        guard cacheWritable else { throw InventoryErrorBridge.message("The unreadable cache must be recovered before making a structured backup") }
        var object: [String: Any] = ["format":"Pantry native backup v1", "items": Dictionary(uniqueKeysWithValues: state.items.map { ($0.id, wire($0)) }), "ledger": Dictionary(uniqueKeysWithValues: history.compactMap { row in guard let id = row["id"] as? String else { return nil }; return (id, row) }), "meta": meta]
        object["nativeState"] = String(data: try JSONEncoder().encode(state), encoding: .utf8)!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Pantry-backup.json")
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
    func clearDevice() throws {
        guard user == nil else { throw InventoryErrorBridge.message("Sign out before removing device-only data") }
        state = DeviceState(); history = []; meta = [:]; cacheWritable = true; try persist()
    }
    func applyWidgetCommands() async {
        guard authenticationReady, !busy else { return }
        guard let directory = try? WidgetStorage.directory(), let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "json" {
            do {
                let command = try JSONDecoder().decode(WidgetPurchaseCommand.self, from: Data(contentsOf: file))
                guard command.accountTag == accountTag else { continue }
                guard state.shopping.contains(where: { $0.id == command.shoppingID }) else { continue }
                try await purchase(command.shoppingID, addInventory: false)
                try FileManager.default.removeItem(at: file)
            } catch { self.error = "Widget purchase remains pending: \(error.localizedDescription)" }
        }
    }
    private func publishWidget() {
        // Home widgets receive safe display rows; accessory views show counts only.
        let recent = history.filter { $0["reason"] as? String == "eaten" }.sorted { ($0["ts"] as? Double ?? 0) > ($1["ts"] as? Double ?? 0) }.prefix(5)
        let snapshot = WidgetSnapshot(accountTag: accountTag,
            low: low.map { .init(id: $0.id, title: $0.name, detail: "\(NSDecimalNumber(decimal: $0.qty)) \($0.unit)") },
            shopping: state.shopping.filter { !$0.purchased }.map { .init(id: $0.id, title: $0.name, detail: NSDecimalNumber(decimal: $0.quantity).stringValue) },
            expiry: expiring.map { .init(id: $0.id, title: $0.name, detail: $0.expirationDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown") },
            recentlyEaten: recent.map { .init(id: $0["id"] as? String ?? UUID().uuidString, title: $0["itemName"] as? String ?? "Food", detail: String(describing: $0["delta"] ?? "")) },
            inboxCount: inbox.count, updated: Date(), syncStatus: status, lastSuccessfulSync: lastSync)
        if let data = try? JSONEncoder().encode(snapshot) { WidgetStorage.defaults?.set(data, forKey: "snapshot") }
        guard let defaults = UserDefaults(suiteName: "group.dev.jacksonwilson.pantry") else { return }
        defaults.set(low.count, forKey: "low"); defaults.set(expiring.count, forKey: "expiry"); defaults.set(inbox.count, forKey: "inbox")
        defaults.set(state.shopping.filter { !$0.purchased }.count, forKey: "shopping"); defaults.set(Date(), forKey: "updated")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
