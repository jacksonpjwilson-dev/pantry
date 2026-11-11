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
        let row: [String: Any] = ["id": op["id"]!, "itemId":"eggs", "reason":"eaten", "delta": -2, "source":op["source"]!, "undone": false]
        XCTAssertTrue(try adapter.plan(document: doc([entry]), items: items, ledger: [row], meta: meta).operations.isEmpty)
        let removed = try adapter.plan(document: doc([]), items: items, ledger: [row], meta: meta)
        XCTAssertEqual(removed.operations.first?["delta"] as? Int, 2)
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
    }
    @MainActor func testUnlinkedAndUnknownFoodMetadata() async throws {
        let result = try adapter().plan(document: doc([["fid":"unknown", "q":1]]), items: items, ledger: [], meta: [:])
        XCTAssertEqual(result.operations.first?["t"] as? String, "inbox")
    }
    @MainActor func testInvalidQuantityDoesNotProduceAdjustment() async throws {
        XCTAssertThrowsError(try adapter().plan(document: doc([["fid":"egg", "q":-2]]), items: items, ledger: [], meta: meta))
    }
    @MainActor func testUnverifiedServingIsBlocked() async throws {
        XCTAssertThrowsError(try adapter().plan(document: doc([["fid":"egg", "q":1]]), items: items, ledger: [], meta: ["links":["egg":["itemId":"eggs", "mode":"auto"]]]))
    }
}
#endif
