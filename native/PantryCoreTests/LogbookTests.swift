#if canImport(JavaScriptCore)
import XCTest
@testable import PantryCore

final class LogbookTests: XCTestCase {
    @MainActor private func adapter() throws -> LegacyLogbookAdapter {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Pantry/engine.js")
        return LegacyLogbookAdapter(script: try String(contentsOf: file))
    }
    private let date = "2026-11-11"
    private var items: [String: Any] { ["eggs": ["id":"eggs", "name":"Eggs", "unit":"count", "qty":12]] }
    private var meta: [String: [String: Any]] { ["links": ["egg": ["itemId":"eggs", "mode":"per", "per":1]]] }
    private func doc(_ entries: [[String: Any]]) -> [String: Any] { ["r": ["food@2026-11-11": ["t": 1, "v": entries]]] }
    @MainActor func testDuplicateAndCorrectionCompatibility() async throws {
        let adapter = try adapter(), entry: [String: Any] = ["fid":"egg", "q":2]
        let initial = try adapter.plan(document: doc([entry]), items: items, ledger: [], meta: meta)
        XCTAssertEqual(initial.operations.filter { $0["t"] as? String == "adjust" }.count, 1)
        let op = initial.operations[0]
        let row: [String: Any] = ["id": op["id"]!, "itemId":"eggs", "unit":"count", "reason":"eaten", "delta": -2, "source":op["source"]!, "undone": false]
        XCTAssertTrue(try adapter.plan(document: doc([entry]), items: items, ledger: [row], meta: meta).operations.isEmpty)
        let removed = try adapter.plan(document: doc([]), items: items, ledger: [row], meta: meta)
        XCTAssertEqual(removed.operations.first?["delta"] as? Int, 2)
        let correction = removed.operations.first!
        let corrected: [String: Any] = ["id": correction["id"]!, "itemId":"eggs", "reason":"correction", "delta":2, "source":correction["source"]!]
        XCTAssertTrue(try adapter.plan(document: doc([]), items: items, ledger: [row, corrected], meta: meta).operations.isEmpty)
        let deletedDay = try adapter.plan(document: ["r": [:]], items: items, ledger: [row], meta: meta)
        XCTAssertEqual(deletedDay.operations.first?["delta"] as? Int, 2)
    }
    @MainActor func testIdenticalOccurrencesAndReordering() async throws {
        let adapter = try adapter(), a: [String: Any] = ["fid":"egg", "q":1], b: [String: Any] = ["fid":"egg", "q":2]
        let first = try adapter.plan(document: doc([a,a,b]), items: items, ledger: [], meta: meta)
        let reordered = try adapter.plan(document: doc([b,a,a]), items: items, ledger: [], meta: meta)
        XCTAssertEqual(Set(first.operations.compactMap { $0["id"] as? String }), Set(reordered.operations.compactMap { $0["id"] as? String }))
        XCTAssertEqual(first.operations.count, 3)
    }
    @MainActor func testReappearanceRequiresReview() async throws {
        let key = "2026-11-11|egg||||1#1"
        let row: [String: Any] = ["id":LegacyIdentity.ledgerID("c", key:key), "reason":"correction", "source":["key":key, "date":date]]
        XCTAssertThrowsError(try adapter().plan(document: doc([["fid":"egg", "q":1]]), items: items, ledger: [row], meta: meta))
        var ignored = meta; ignored["ignored"] = ["egg":true]
        XCTAssertTrue(try adapter().plan(document: doc([["fid":"egg", "q":1]]), items: items, ledger: [row], meta: ignored).operations.isEmpty)
    }
    @MainActor func testUnlinkedAndUnknownFoodMetadata() async throws {
        let result = try adapter().plan(document: doc([["fid":"unknown", "q":1]]), items: items, ledger: [], meta: [:])
        XCTAssertEqual(result.operations.first?["t"] as? String, "inbox")
    }
    @MainActor func testInvalidQuantityDoesNotProduceAdjustment() async throws {
        XCTAssertThrowsError(try adapter().plan(document: doc([["fid":"egg", "q":-2]]), items: items, ledger: [], meta: meta))
    }
    @MainActor func testRecordedUnitMismatchCannotFallBackToOneServing() async throws {
        let adapter = try adapter()
        let items: [String: Any] = ["rice":["id":"rice", "name":"Rice", "unit":"g", "qty":1000]]
        let meta: [String: [String: Any]] = ["links":["rice":["itemId":"rice", "mode":"auto"]]]
        var document: [String: Any] = ["r":["foods#rice":["v":["id":"rice", "name":"Rice", "kind":"measured", "size":100, "unit":"g"]], "food@2026-11-11":["t":1, "v":[["fid":"rice", "q":1, "amt":150, "unit":"g"]]]]]
        let valid = try adapter.plan(document: document, items: items, ledger: [], meta: meta)
        XCTAssertEqual(valid.operations.first?["delta"] as? Int, -150)
        var records = document["r"] as! [String: Any]
        records["food@2026-11-11"] = ["t":1, "v":[["fid":"rice", "q":1, "amt":150, "unit":"ml"]]]
        document["r"] = records
        XCTAssertThrowsError(try adapter.plan(document: document, items: items, ledger: [], meta: meta))
    }
    @MainActor func testCompleteLedgerRecognizesOldConsumption() async throws {
        let adapter = try adapter(), entry: [String: Any] = ["fid":"egg", "q":2]
        let op = try adapter.plan(document: doc([entry]), items: items, ledger: [], meta: meta).operations.first!
        var ledger: [[String: Any]] = (0..<600).map { ["id":"manual-\($0)", "reason":"manual"] }
        ledger.append(["id":op["id"]!, "itemId":"eggs", "unit":"count", "reason":"eaten", "delta":-2, "source":op["source"]!])
        XCTAssertTrue(try adapter.plan(document: doc([entry]), items: items, ledger: ledger, meta: meta).operations.isEmpty)
    }
    @MainActor func testUnsupportedSnapshotCannotRestoreHistoricalStock() async throws {
        let adapter = try adapter(), entry: [String: Any] = ["fid":"egg", "q":2]
        let op = try adapter.plan(document: doc([entry]), items: items, ledger: [], meta: meta).operations.first!
        let row: [String: Any] = ["id":op["id"]!, "itemId":"eggs", "unit":"count", "reason":"eaten", "delta":-2, "source":op["source"]!]
        XCTAssertThrowsError(try adapter.plan(document: ["nutrition":[:]], items: items, ledger: [row], meta: meta))
        XCTAssertThrowsError(try adapter.plan(document: ["r":"unsupported"], items: items, ledger: [row], meta: meta))
    }
    @MainActor func testMalformedDayCannotBeTreatedAsDeletion() async throws {
        let adapter = try adapter(), entry: [String: Any] = ["fid":"egg", "q":2]
        let op = try adapter.plan(document: doc([entry]), items: items, ledger: [], meta: meta).operations.first!
        let row: [String: Any] = ["id":op["id"]!, "itemId":"eggs", "unit":"count", "reason":"eaten", "delta":-2, "source":op["source"]!]
        let malformedValues: [Any] = ["invalid-json", ["unexpected":"object"], [["q":2]]]
        for value in malformedValues {
            let invalid: [String: Any] = ["r":["food@2026-11-11":["t":2, "v":value]]]
            XCTAssertThrowsError(try adapter.plan(document: invalid, items: items, ledger: [row], meta: meta))
        }
    }
    @MainActor func testChangingRelationshipDoesNotReapplyHistoricalConsumption() async throws {
        let adapter = try adapter(), entry: [String: Any] = ["fid":"egg", "q":2]
        let op = try adapter.plan(document: doc([entry]), items: items, ledger: [], meta: meta).operations.first!
        let row: [String: Any] = ["id":op["id"]!, "itemId":"eggs", "unit":"count", "reason":"eaten", "delta":-2, "source":op["source"]!]
        var changed = meta; changed["links"] = ["egg":["itemId":"eggs", "mode":"per", "per":12]]
        XCTAssertTrue(try adapter.plan(document: doc([entry]), items: items, ledger: [row], meta: changed).operations.isEmpty)
    }
    @MainActor func testRemovingOneEquivalentDuplicateRestoresOneDeduction() async throws {
        let adapter = try adapter(), entry: [String: Any] = ["fid":"egg", "q":2]
        let operations = try adapter.plan(document: doc([entry,entry]), items: items, ledger: [], meta: meta).operations
        let rows: [[String: Any]] = operations.map { ["id":$0["id"]!, "itemId":"eggs", "unit":"count", "reason":"eaten", "delta":-2, "source":$0["source"]!] }
        let result = try adapter.plan(document: doc([entry]), items: items, ledger: rows, meta: meta)
        XCTAssertEqual(result.operations.count, 1)
        XCTAssertEqual(result.operations.first?["reason"] as? String, "correction")
        XCTAssertEqual(result.operations.first?["delta"] as? Int, 2)
    }
    @MainActor func testRemovingDifferentlyAppliedDuplicatesRequiresReview() async throws {
        let adapter = try adapter(), entry: [String: Any] = ["fid":"egg", "q":2]
        let operations = try adapter.plan(document: doc([entry,entry]), items: items, ledger: [], meta: meta).operations
        let rows: [[String: Any]] = operations.enumerated().map { index, op in ["id":op["id"]!, "itemId":"eggs", "unit":"count", "reason":"eaten", "delta":index == 0 ? -2 : -1, "source":op["source"]!] }
        XCTAssertThrowsError(try adapter.plan(document: doc([entry]), items: items, ledger: rows, meta: meta))
    }
    @MainActor func testRemovingAllMixedDuplicatesCanRestoreEveryAppliedAmount() async throws {
        let adapter = try adapter(), entry: [String: Any] = ["fid":"egg", "q":2]
        let operations = try adapter.plan(document: doc([entry,entry]), items: items, ledger: [], meta: meta).operations
        let rows: [[String: Any]] = operations.enumerated().map { index, op in ["id":op["id"]!, "itemId":"eggs", "unit":"count", "reason":"eaten", "delta":index == 0 ? -2 : -1, "source":op["source"]!] }
        let result = try adapter.plan(document: doc([]), items: items, ledger: rows, meta: meta)
        XCTAssertEqual(result.operations.count, 2)
        XCTAssertEqual(result.operations.reduce(0.0) { $0 + ($1["delta"] as? NSNumber)!.doubleValue }, 3)
    }
    @MainActor func testUndoMarkerPreventsRestorationWhenFlagIsStale() async throws {
        let adapter = try adapter(), entry: [String: Any] = ["fid":"egg", "q":2]
        let op = try adapter.plan(document: doc([entry]), items: items, ledger: [], meta: meta).operations.first!
        let originalID = op["id"] as! String
        let original: [String: Any] = ["id":originalID, "itemId":"eggs", "unit":"count", "reason":"eaten", "delta":-2, "source":op["source"]!, "undone":false]
        let undo: [String: Any] = ["id":"u_" + originalID, "itemId":"eggs", "unit":"count", "reason":"undo", "delta":2, "source":["of":originalID]]
        XCTAssertTrue(try adapter.plan(document: doc([]), items: items, ledger: [original,undo], meta: meta).operations.isEmpty)
    }
    @MainActor func testCorrectionUsesTheRecordedLedgerUnit() async throws {
        let key = "2026-11-11|rice|m1|150|g|1#1"
        let original: [String: Any] = ["id":LegacyIdentity.ledgerID("e", key:key), "itemId":"rice", "unit":"g", "reason":"eaten", "delta":-150, "source":["key":key,"date":date,"fid":"rice"]]
        let current: [String: Any] = ["rice":["id":"rice","name":"Rice","unit":"kg","qty":0.85]]
        let result = try adapter().plan(document: ["r":[:]], items: current, ledger: [original], meta: [:])
        XCTAssertEqual((result.operations.first?["delta"] as? NSNumber)?.decimalValue, Decimal(string:"0.15"))
    }
    @MainActor func testDisabledLegacyIntegrationDoesNotPlanDeductions() async throws {
        var disabled = meta; disabled["state"] = ["setup":["linkV2":false]]
        XCTAssertTrue(try adapter().plan(document: doc([["fid":"egg", "q":2]]), items: items, ledger: [], meta: disabled).operations.isEmpty)
    }
    @MainActor func testUnverifiedServingIsBlocked() async throws {
        XCTAssertThrowsError(try adapter().plan(document: doc([["fid":"egg", "q":1]]), items: items, ledger: [], meta: ["links":["egg":["itemId":"eggs", "mode":"auto"]]]))
    }
}
#endif
