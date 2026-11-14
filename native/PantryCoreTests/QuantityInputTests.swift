import XCTest
@testable import PantryCore

final class QuantityInputTests: XCTestCase {
    private let english = Locale(identifier: "en_CA")
    func testWholeNumericFieldsAndScientificNotation() {
        XCTAssertEqual(QuantityInput.parse(" 150.25 ", locale: english), Decimal(string:"150.25"))
        XCTAssertEqual(QuantityInput.parse("1e3", locale: english), 1000)
        XCTAssertEqual(QuantityInput.parse(".5", locale: english), Decimal(string:"0.5"))
    }
    func testUnitsGroupingAndPartialNumbersCannotSilentlyChangeTheAmount() {
        for text in ["150 g", "1,000", "1.2.3", "12oops", "NaN", "Infinity", "-1", ""] {
            XCTAssertNil(QuantityInput.parse(text, locale: english), text)
        }
    }
    func testLocaleDecimalSeparatorsAndEditableFormatting() {
        let french = Locale(identifier: "fr_CA"), german = Locale(identifier: "de_DE")
        XCTAssertEqual(QuantityInput.parse("1,5", locale: french), Decimal(string:"1.5"))
        XCTAssertEqual(QuantityInput.formatted(Decimal(string:"1000.5")!, locale: french), "1000,5")
        XCTAssertNil(QuantityInput.parse("1.000", locale: german))
    }
    func testLocalizedDigits() {
        XCTAssertEqual(QuantityInput.parse("١٢٫٥", locale: Locale(identifier:"ar_SA")), Decimal(string:"12.5"))
    }
}
