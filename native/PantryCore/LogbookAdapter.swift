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
    func plan(document: [String: Any], items: [String: Any], ledger: [[String: Any]], meta: [String: [String: Any]]) throws -> LogbookPlan {
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
        let ops = result["ops"] as? [[String: Any]] ?? []
        // Existing correction IDs permanently occupy synthetic identities. Surface ambiguity.
        let ids = Set(ledger.compactMap { $0["id"] as? String })
        for (date, value) in days {
            let entries = (value as? [String: Any])?["entries"] as? [[String: Any]] ?? []
            let keys = engine.invokeMethod("entryKeys", withArguments: [date, entries])?.toArray() as? [[String: Any]] ?? []
            for entry in keys {
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
