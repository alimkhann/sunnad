import XCTest

final class sunnad_iosUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testQuoteShareOpensShareFlow() throws {
        let app = makeApp()
        app.launchEnvironment["SUNNAD_DEBUG_TAB"] = "today"
        app.launchEnvironment["SUNNAD_UI_TEST_MODE"] = "1"
        app.launch()

        let quoteCard = app.buttons["quote.card.open"]
        XCTAssertTrue(quoteCard.waitForExistence(timeout: 5))
        quoteCard.tap()

        let shareButton = app.buttons["quote.share.button"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5))
        shareButton.tap()

        let expectation = NSPredicate(format: "value == %@", "1")
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: expectation, object: shareButton)],
            timeout: 5
        )
        XCTAssertEqual(result, .completed)
    }

    @MainActor
    func testAuthCloseButtonReturnsFromGroupsSignIn() throws {
        let app = makeApp()
        app.launchEnvironment["SUNNAD_DEBUG_TAB"] = "groups"
        app.launchEnvironment["SUNNAD_DEBUG_USER"] = "guest"
        app.launch()

        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()

        let closeButton = app.buttons["auth.close.button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testReminderSuppressedAfterCompletion() throws {
        let app = makeApp()
        app.launchEnvironment["SUNNAD_DEBUG_TAB"] = "today"
        app.launchEnvironment["SUNNAD_UI_TEST_MODE"] = "1"
        app.launch()

        let pendingCount = app.staticTexts["debug.reminder.pending.count"]
        XCTAssertTrue(pendingCount.waitForExistence(timeout: 8))

        let initialCount = Int(pendingCount.label) ?? 0

        let toggleQuery = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "habit.toggle."))
        let firstToggle = toggleQuery.firstMatch
        XCTAssertTrue(firstToggle.waitForExistence(timeout: 5))
        firstToggle.tap()

        let expected = max(0, initialCount - 1)
        let expectation = NSPredicate(format: "label == %@", "\(expected)")
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: expectation, object: pendingCount)],
            timeout: 8
        )
        XCTAssertEqual(result, .completed)
    }

    @MainActor
    func testReorderPersistsAcrossRelaunch() throws {
        let app = makeApp()
        app.launchEnvironment["SUNNAD_DEBUG_TAB"] = "today"
        app.launch()

        let manageButton = app.buttons["today.manage.button"]
        XCTAssertTrue(manageButton.waitForExistence(timeout: 5))
        manageButton.tap()

        let reorderButton = app.buttons["schedule.reorder.button"]
        XCTAssertTrue(reorderButton.waitForExistence(timeout: 5))
        reorderButton.tap()

        let firstRowBefore = app.buttons["schedule.habit.row.0"]
        let secondRowBefore = app.buttons["schedule.habit.row.1"]
        XCTAssertTrue(firstRowBefore.waitForExistence(timeout: 5))
        XCTAssertTrue(secondRowBefore.waitForExistence(timeout: 5))
        let firstTitleBefore = firstRowBefore.label

        let firstHandle = app.images["schedule.reorder.handle.0"]
        let thirdHandle = app.images["schedule.reorder.handle.2"]
        XCTAssertTrue(firstHandle.waitForExistence(timeout: 5))
        XCTAssertTrue(thirdHandle.waitForExistence(timeout: 5))

        let firstRowAfterDrag = app.buttons["schedule.habit.row.0"]
        XCTAssertTrue(firstRowAfterDrag.waitForExistence(timeout: 5))
        let movedPredicate = NSPredicate(format: "label != %@", firstTitleBefore)

        firstHandle.press(forDuration: 1.4, thenDragTo: thirdHandle)
        var moveResult = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: movedPredicate, object: firstRowAfterDrag)],
            timeout: 4
        )
        if moveResult != .completed {
            firstHandle.press(forDuration: 1.4, thenDragTo: thirdHandle)
            moveResult = XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: movedPredicate, object: firstRowAfterDrag)],
                timeout: 4
            )
        }
        XCTAssertEqual(moveResult, .completed)
        let firstTitleAfterDrag = firstRowAfterDrag.label

        reorderButton.tap()
        app.buttons["back.compact.button"].tap()

        app.terminate()
        app.launch()

        XCTAssertTrue(manageButton.waitForExistence(timeout: 5))
        manageButton.tap()

        let firstRowAfter = app.buttons["schedule.habit.row.0"]
        XCTAssertTrue(firstRowAfter.waitForExistence(timeout: 5))
        let firstTitleAfter = firstRowAfter.label

        XCTAssertEqual(firstTitleAfter, firstTitleAfterDrag)
        XCTAssertNotEqual(firstTitleAfter, firstTitleBefore)
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SUNNAD_DEBUG_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["SUNNAD_DEBUG_LANGUAGE"] = "en"
        return app
    }
}
