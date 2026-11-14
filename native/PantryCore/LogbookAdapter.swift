import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore

/// Reuses the audited production parser and identifiers. Never accesses Logbook writes.
struct LogbookPlan {
    var operations: [[String: Any]]
    var cursor: Double
}
@MainActor final class LegacyLogbookAdapter {
    private let context: JSContext
    init(script: String? = nil) {
        context = JSContext()!
        if let script { context.evaluateScript(script); return }
        if let url = Bundle.main.url(forResource: "engine", withExtension: "js"), let script = try? String(contentsOf: url) { context.evaluateScript(script) }
    }
    func plan(document: [String: Any], items: [String: Any], ledger originalLedger: [[String: Any]], meta: [String: [String: Any]]) throws -> LogbookPlan {
        guard LogbookConnectionPolicy.enabled(in: meta) else { return LogbookPlan(operations: [], cursor: 0) }
        let byID = originalLedger.reduce(into: [String: [String: Any]]()) { result, row in if let id = row["id"] as? String { result[id] = row } }
        let ledger = originalLedger.map { row -> [String: Any] in
            guard let id = row["id"] as? String, let undo = byID["u_" + id], undo["reason"] as? String == "undo", undo["undone"] as? Bool != true,
                  (undo["source"] as? [String: Any])?["of"] as? String == id else { return row }
            var effective = row; effective["undone"] = true; return effective
        }
        guard let records = document["r"] as? [String: Any] else { throw InventoryErrorBridge.message("This source is not a Logbook v2 snapshot. Inventory was not changed.") }
        for (id, value) in records where id.range(of: #"^food@\d{4}-\d\d-\d\d$"#, options: .regularExpression) != nil {
            guard let record = value as? [String: Any] else { throw InventoryErrorBridge.message("Logbook day \(id) is unreadable. Inventory was not changed.") }
            if (record["d"] as? NSNumber)?.boolValue == true || (record["d"] as? String).map({ !$0.isEmpty }) == true { continue }
            let parsed: Any?
            if let text = record["v"] as? String {
                guard let data = text.data(using: .utf8), let decoded = try? JSONSerialization.jsonObject(with: data) else { throw InventoryErrorBridge.message("Logbook day \(id) contains invalid JSON. Inventory was not changed.") }
                parsed = decoded
            } else { parsed = record["v"] }
            guard let entries = parsed as? [Any] else { throw InventoryErrorBridge.message("Logbook day \(id) is not an entry array. Inventory was not changed.") }
            for entry in entries where !(entry is NSNull) {
                guard let food = entry as? [String: Any], let fid = food["fid"], !(fid is NSNull) else { throw InventoryErrorBridge.message("Logbook day \(id) contains an entry without an identity. Inventory was not changed.") }
            }
        }
        context.exception = nil
        guard let engine = context.objectForKeyedSubscript("PE"), !engine.isUndefined else { throw InventoryErrorBridge.message("Bundled Logbook engine unavailable") }
        let v2 = engine.invokeMethod("readV2Cloud", withArguments: [document])!
        // Full server ledger, full scan. Include deleted days for restoration.
        var days = v2.forProperty("days")!.toDictionary() as? [String: Any] ?? [:]
        for row in ledger where row["reason"] as? String == "eaten" {
            if let source = row["source"] as? [String: Any], let date = source["date"] as? String, days[date] == nil { days[date] = ["t": 1, "entries": []] }
        }
        v2.setValue(days, forProperty: "days")
        let state: [String: Any] = ["items": items, "ledger": ledger, "links": meta["links"] ?? [:], "inbox": meta["inbox"] ?? [:], "ignored": meta["ignored"] ?? [:], "startDate": meta["state"]?["startDate"] ?? "0000-00-00", "lastProcessed": -1]
        guard let result = engine.invokeMethod("plan", withArguments: [v2 as Any, state])?.toDictionary(), context.exception == nil else { throw InventoryErrorBridge.message("Logbook schema could not be read") }
        var ops = result["ops"] as? [[String: Any]] ?? []
        for index in ops.indices where ops[index]["t"] as? String == "adjust" {
            guard let delta = ops[index]["delta"] as? NSNumber, delta.doubleValue.isFinite else { throw InventoryErrorBridge.message("A historical quantity is invalid. Inventory was not changed.") }
            if ops[index]["reason"] as? String == "correction" {
                guard let source = ops[index]["source"] as? [String: Any], let originalID = source["of"] as? String, let original = byID[originalID],
                      let oldUnit = original["unit"] as? String, let itemID = ops[index]["itemId"] as? String,
                      let current = items[itemID] as? [String: Any], let unit = current["unit"] as? String,
                      let number = original["delta"] as? NSNumber, number.doubleValue.isFinite, let amount = Decimal(string: number.stringValue) else { throw InventoryError.verificationRequired }
                ops[index]["delta"] = NSDecimalNumber(decimal: try Measures.reversal(of: amount, recordedUnit: oldUnit, currentUnit: unit))
            }
        }
        // Existing correction IDs permanently occupy synthetic identities. Surface ambiguity.
        let ids = Set(ledger.compactMap { $0["id"] as? String })
        var presentKeys = Set<String>()
        for (date, value) in days {
            let entries = (value as? [String: Any])?["entries"] as? [[String: Any]] ?? []
            let keys = engine.invokeMethod("entryKeys", withArguments: [date, entries])?.toArray() as? [[String: Any]] ?? []
            for entry in keys {
                if let key = entry["key"] as? String { presentKeys.insert(key) }
                if let record = entry["e"] as? [String: Any] {
                    let fid = String(describing: record["fid"] ?? "")
                    let ignored = meta["ignored"]?[fid]
                    if (ignored as? NSNumber)?.boolValue == true || (ignored as? String).map({ !$0.isEmpty }) == true { continue }
                }
                if let key = entry["key"] as? String, let correction = engine.invokeMethod("ledgerId", withArguments: ["c", key])?.toString(), ids.contains(correction) {
                    throw InventoryErrorBridge.message("A previously corrected Logbook occurrence has reappeared. Review history before syncing; legacy source IDs cannot identify this safely.")
                }
            }
        }
        // Equal source entries are only interchangeable when their applied bindings match.
        // A later relink or a clamped deduction can make ordinal-based removal ambiguous.
        func baseKey(_ key: String) -> String {
            guard let marker = key.lastIndex(of: "#"), Int(key[key.index(after: marker)...]) != nil else { return key }
            return String(key[..<marker])
        }
        struct Binding: Hashable { var item: String; var unit: String; var applied: String; var requested: String; var undone: Bool }
        var bindings: [String: Set<Binding>] = [:], groupKeys: [String: Set<String>] = [:]
        for row in ledger where row["reason"] as? String == "eaten" {
            guard let source = row["source"] as? [String: Any], let key = source["key"] as? String,
                  !ids.contains(LegacyIdentity.ledgerID("c", key: key)) else { continue }
            let applied = (row["delta"] as? NSNumber)?.stringValue ?? "unknown"
            let binding = Binding(item: row["itemId"] as? String ?? "", unit: row["unit"] as? String ?? "", applied: applied,
                                  requested: (row["requestedDelta"] as? NSNumber)?.stringValue ?? applied, undone: row["undone"] as? Bool == true)
            bindings[baseKey(key), default: []].insert(binding); groupKeys[baseKey(key), default: []].insert(key)
        }
        for op in ops where op["reason"] as? String == "correction" {
            if let source = op["source"] as? [String: Any], let key = source["key"] as? String,
               (bindings[baseKey(key)]?.count ?? 0) > 1,
               groupKeys[baseKey(key)]?.contains(where: { presentKeys.contains($0) }) == true {
                throw InventoryErrorBridge.message("Identical Logbook occurrences have different historical deductions. Review history; legacy IDs cannot identify which occurrence was removed.")
            }
        }
        let foods = v2.forProperty("foods")?.toDictionary() as? [String: Any] ?? [:]
        for op in ops where op["t"] as? String == "adjust" && op["reason"] as? String == "eaten" {
            guard let source = op["source"] as? [String: Any] else { continue }
            guard let delta = op["delta"] as? NSNumber, delta.doubleValue.isFinite, delta.doubleValue <= 0,
                  let quantity = source["q"] as? NSNumber, quantity.doubleValue.isFinite, quantity.doubleValue >= 0 else { throw InventoryErrorBridge.message("Logbook contains an invalid quantity; no planned operations were applied") }
            let fid = String(describing: source["fid"] ?? "")
            let link = meta["links"]?[fid] as? [String: Any] ?? [:]
            let food = foods[fid] as? [String: Any] ?? [:]
            let item = items[op["itemId"] as? String ?? ""] as? [String: Any] ?? [:]
            let explicit = link["mode"] as? String == "per" && ((link["per"] as? NSNumber)?.doubleValue ?? 0) > 0
            var recordedUnit = food["unit"] as? String ?? ""
            if let amount = source["amt"], !(amount is NSNull) {
                guard let number = amount as? NSNumber, number.doubleValue.isFinite, number.doubleValue >= 0 else { throw InventoryErrorBridge.message("Logbook contains an invalid measured amount") }
                if !explicit, let unit = source["unit"] as? String, !unit.isEmpty {
                    guard let normalized = engine.invokeMethod("unitNorm", withArguments: [unit]), !normalized.isNull, !normalized.isUndefined else { throw InventoryError.verificationRequired }
                    recordedUnit = normalized.toString()
                }
            }
            let measured = food["kind"] as? String == "measured" && engine.invokeMethod("convU", withArguments: [1, recordedUnit, item["unit"] ?? ""])?.isNull == false
            guard explicit || measured else { throw InventoryErrorBridge.message("Verify the serving relationship for \(source["food"] ?? "this food") before syncing.") }
        }
        return LogbookPlan(operations: ops, cursor: result["cursor"] as? Double ?? 0)
    }
}

#endif
enum InventoryErrorBridge: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
