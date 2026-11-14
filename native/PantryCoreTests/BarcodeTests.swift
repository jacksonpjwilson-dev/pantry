import XCTest
@testable import PantryCore

final class BarcodeTests: XCTestCase {
    func testUPCAAndScannerEAN13IdentifyTheSameProduct() {
        XCTAssertTrue(BarcodeIdentity.matches("012345678905", "0012345678905"))
        XCTAssertTrue(BarcodeIdentity.matches("0012345678905", " 012345678905\n"))
    }
    func testDifferentProductsAndCaseSensitiveCodesStayDistinct() {
        XCTAssertFalse(BarcodeIdentity.matches("012345678905", "012345678912"))
        XCTAssertFalse(BarcodeIdentity.matches("96385074", "96385075"))
        XCTAssertFalse(BarcodeIdentity.matches("ABC-1", "abc-1"))
        XCTAssertEqual(BarcodeIdentity.canonical("96385074"), "96385074")
    }
    func testMissingBarcodesNeverMatch() {
        XCTAssertFalse(BarcodeIdentity.matches(nil, "012345678905"))
        XCTAssertFalse(BarcodeIdentity.matches("", ""))
        XCTAssertFalse(BarcodeIdentity.matches(" \n", ""))
    }
}
