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
        // Metadata edits must retain stock; a linked purchase must add exactly once.
        app.navigationBars.buttons["Edit"].tap()
        let threshold = app.textFields["Low-stock threshold"]
        XCTAssertTrue(threshold.waitForExistence(timeout: 5)); threshold.tap(); threshold.typeText("2")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["1 count"].waitForExistence(timeout: 5))
        if !app.buttons["Add to shopping list"].isHittable { app.swipeUp() }
        app.buttons["Add to shopping list"].tap()
        app.tabBars.buttons["Shopping"].tap()
        let shoppingRow = app.buttons.containing(.staticText, identifier: String(name)).firstMatch
        XCTAssertTrue(shoppingRow.waitForExistence(timeout: 5)); shoppingRow.tap()
        app.buttons["Complete and add to inventory"].tap()
        app.tabBars.buttons["Inventory"].tap(); app.swipeDown()
        XCTAssertTrue(app.staticTexts["2 count"].waitForExistence(timeout: 5))
        app.terminate(); app.launch(); app.tabBars.buttons["Inventory"].tap()
        app.staticTexts[String(name)].tap()
        XCTAssertTrue(app.staticTexts["2 count"].waitForExistence(timeout: 5))
        if !app.buttons["Delete item"].isHittable { app.swipeUp() }
        app.buttons["Delete item"].tap()
        app.buttons["Delete"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts[String(name)])
        waitForExpectations(timeout: 5)
    }
    @MainActor func testManualBarcodeOpensAnUnknownItemWithoutGuessingDetails() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch()
        app.tabBars.buttons["Inventory"].tap()
        app.navigationBars.buttons["Scan"].tap()
        let barcode = app.textFields["UPC or EAN barcode"]
        XCTAssertTrue(barcode.waitForExistence(timeout: 10)); barcode.tap(); barcode.typeText("012345678905")
        app.buttons["Use barcode"].tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertTrue(["", "Name"].contains(name.value as? String ?? "unexpected")) // Empty field or placeholder; no guessed product.
        app.navigationBars.buttons["Cancel"].tap()
    }

    @MainActor func testEmulatorAuthenticationStockAndAccountSeparation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PANTRY_EMULATOR_UI"] == "1", "Run through the isolated Firebase emulator workflow")
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing", "--firebase-emulator"]; app.launch()
        func signIn(_ email: String) {
            app.tabBars.buttons["Settings"].tap()
            let field = app.textFields["Email"]
            XCTAssertTrue(field.waitForExistence(timeout: 10)); field.tap(); field.typeText(email)
            app.secureTextFields["Password"].tap(); app.secureTextFields["Password"].typeText("SyntheticPassword123!")
            XCTAssertTrue(app.buttons["Sign in"].isEnabled, app.debugDescription)
            app.buttons["Sign in"].tap()
            XCTAssertTrue(app.buttons["Sign out"].waitForExistence(timeout: 15), app.debugDescription)
            expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["Sign out"])
            waitForExpectations(timeout: 15)
            XCTAssertFalse(app.alerts["Pantry needs attention"].exists, app.debugDescription)
        }
        signIn("alice@pantry.example")
        app.tabBars.buttons["Inventory"].tap(); app.navigationBars.buttons["Add"].tap()
        let name = "Cloud fixture " + String(UUID().uuidString.prefix(8))
        app.textFields["Name"].tap(); app.textFields["Name"].typeText(name); app.navigationBars.buttons["Save"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.navigationBars["Food details"])
        waitForExpectations(timeout: 30)
        XCTAssertFalse(app.alerts["Pantry needs attention"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 15)); app.staticTexts[name].tap()
        app.buttons["Bought"].tap(); XCTAssertTrue(app.staticTexts["1 count"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["Sign out"])
        waitForExpectations(timeout: 15); app.buttons["Sign out"].tap()
        signIn("bob@pantry.example")
        app.tabBars.buttons["Inventory"].tap(); XCTAssertFalse(app.staticTexts[name].exists)
        app.tabBars.buttons["Settings"].tap()
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["Sign out"])
        waitForExpectations(timeout: 15); app.buttons["Sign out"].tap()
        signIn("alice@pantry.example")
        app.tabBars.buttons["Inventory"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 15)); app.staticTexts[name].tap()
        XCTAssertTrue(app.staticTexts["1 count"].waitForExistence(timeout: 15))
        // Deleting this synthetic cloud item retains its ledger, matching production semantics.
        if !app.buttons["Delete item"].isHittable { app.swipeUp() }
        app.buttons["Delete item"].tap(); app.buttons["Delete"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts[name])
        waitForExpectations(timeout: 15)
    }

}
