import XCTest

final class PantryUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor func testOfflineInventoryPurchaseUndoAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] // The app disables Firebase for this argument.
        app.launch()
        let inventory = app.tabBars.buttons["Inventory"]
        XCTAssertTrue(inventory.waitForExistence(timeout: 15)); inventory.tap()
        app.navigationBars.buttons["Add"].tap()
        let name = "UI test " + String(UUID().uuidString.prefix(8))
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5)); nameField.tap(); nameField.typeText(String(name))
        app.navigationBars.buttons["Save"].tap()
        let item = app.staticTexts[String(name)]
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.tap()
        app.buttons["Bought"].tap()
        XCTAssertTrue(app.staticTexts["1 count"].waitForExistence(timeout: 5))
        app.buttons["Used"].tap()
        XCTAssertTrue(app.staticTexts["0 count"].waitForExistence(timeout: 5))
        app.buttons["Item history"].tap()
        XCTAssertTrue(app.staticTexts["1 → 0 count · manual"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "Undo").firstMatch.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["1 count"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.tabBars.buttons["Inventory"].tap()
        XCTAssertTrue(app.staticTexts[String(name)].waitForExistence(timeout: 5))
        app.staticTexts[String(name)].tap()
        XCTAssertTrue(app.staticTexts["1 count"].waitForExistence(timeout: 5))
        if !app.buttons["Delete item"].isHittable { app.swipeUp() }
        app.buttons["Delete item"].tap()
        app.buttons["Delete"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts[String(name)])
        waitForExpectations(timeout: 5)
    }
}
