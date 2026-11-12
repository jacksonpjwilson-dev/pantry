import XCTest
@testable import PantryCore

final class InventoryTests: XCTestCase {
    func testConversions() throws {
        XCTAssertEqual(try Measures.convert(1, from: "kg", to: "g"), 1000)
        XCTAssertEqual(try Measures.convert(1, from: "cup", to: "ml"), 240)
        XCTAssertEqual(try Measures.convert(1, from: "lb", to: "g"), Decimal(string: "453.59237"))
        XCTAssertThrowsError(try Measures.convert(1, from: "g", to: "ml"))
        XCTAssertThrowsError(try Measures.convert(1, from: "serving", to: "g"))
        XCTAssertThrowsError(try Measures.convert(-1, from: "g", to: "kg"))
    }
    func testClampedAccountingAndUndo() throws {
        let op = Adjustment(itemId: "egg", delta: -15, reason: "eaten")
        let result = try op.apply(to: 12)
        XCTAssertEqual(result.after, 0); XCTAssertEqual(result.applied, -12); XCTAssertEqual(result.unfulfilled, -3)
        let undo = try Adjustment(itemId: "egg", delta: -result.applied, reason: "undo").apply(to: result.after)
        XCTAssertEqual(undo.after, 12)
    }
    func testLowStockIncludesThreshold() {
        var item = InventoryItem(name: "Rice", qty: 200, unit: "g", lowAt: 200)
        XCTAssertEqual(item.status, "low"); item.qty = 0; XCTAssertEqual(item.status, "out"); item.qty = 201; XCTAssertEqual(item.status, "ok")
    }
    func testPurchaseIdentitySurvivesEncoding() throws {
        let item = ShoppingItem(name: "Eggs", itemId: "legacy-egg")
        let decoded = try JSONDecoder().decode(ShoppingItem.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(decoded.purchaseOperationID, item.purchaseOperationID)
        XCTAssertNotEqual(ShoppingItem(name: "Eggs").purchaseOperationID, item.purchaseOperationID)
    }
    func testExpiryUnknownAndOutOfStock() {
        let now = Date(timeIntervalSince1970: 1800000000)
        var item = InventoryItem(name: "Milk", qty: 1)
        XCTAssertFalse(Expiry.upcoming(item, now: now, days: 7))
        item.expirationDate = now.addingTimeInterval(86400)
        XCTAssertTrue(Expiry.upcoming(item, now: now, days: 7))
        item.qty = 0; XCTAssertFalse(Expiry.upcoming(item, now: now, days: 7))
    }
    func testLegacyUTF16HashFixtures() {
        XCTAssertEqual(LegacyIdentity.hash("2026-11-11|egg|m1|||2#1"), "gcjm6w1b2cs9y")
        XCTAssertEqual(LegacyIdentity.hash("🍎"), "1bhwpv335rzr")
    }
    func testLocalAndCloudAccountScopesCannotCollide() {
        XCTAssertNotEqual(AccountScope.cloud("device"), AccountScope.device)
        XCTAssertNotEqual(AccountScope.cloud("alice"), AccountScope.cloud("bob"))
        XCTAssertNotEqual(AccountScope.cloud("alice"), "alice")
    }
    func testInvalidArithmeticIsRejected() {
        XCTAssertThrowsError(try Adjustment(itemId: "rice", delta: .nan, reason: "manual").apply(to: 1))
        XCTAssertThrowsError(try Adjustment(itemId: "rice", delta: 1, reason: "manual").apply(to: -1))
        XCTAssertThrowsError(try Measures.convert(.nan, from: "kg", to: "g"))
    }
    func testPrecision() throws {
        XCTAssertEqual(try Adjustment(itemId: "rice", delta: Decimal(string: "-0.125")!, reason: "eaten").apply(to: 1).after, Decimal(string: "0.875"))
    }
}
