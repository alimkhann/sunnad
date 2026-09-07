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
        let secondHandle = app.images["schedule.reorder.handle.1"]
        XCTAssertTrue(firstHandle.waitForExistence(timeout: 5))
        XCTAssertTrue(secondHandle.waitForExistence(timeout: 5))

        let firstRowAfterDrag = app.buttons["schedule.habit.row.0"]
        XCTAssertTrue(firstRowAfterDrag.waitForExistence(timeout: 5))
        let movedPredicate = NSPredicate(format: "label != %@", firstTitleBefore)

        firstHandle.press(forDuration: 1.4, thenDragTo: secondHandle)
        var moveResult = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: movedPredicate, object: firstRowAfterDrag)],
            timeout: 4
        )
        if moveResult != .completed {
            firstHandle.press(forDuration: 1.4, thenDragTo: secondHandle)
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
        app.launchEnvironment.removeValue(forKey: "SUNNAD_UI_TEST_RESET_HABITS")
        app.launch()

        XCTAssertTrue(manageButton.waitForExistence(timeout: 5))
        manageButton.tap()

        let firstRowAfter = app.buttons["schedule.habit.row.0"]
        XCTAssertTrue(firstRowAfter.waitForExistence(timeout: 5))
        let firstTitleAfter = firstRowAfter.label

        XCTAssertEqual(firstTitleAfter, firstTitleAfterDrag)
        XCTAssertNotEqual(firstTitleAfter, firstTitleBefore)
    }

    @MainActor
    func testFirstWinOnboardingCreatesHabitWithoutNotificationPrompt() throws {
        let app = makeOnboardingApp()
        app.launch()

        let getStarted = app.buttons["onboarding.get_started.button"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        let starterHabit = app.buttons["onboarding.template.morning-dhikr"]
        XCTAssertTrue(starterHabit.waitForExistence(timeout: 5))
        starterHabit.tap()

        let continueButton = app.buttons["onboarding.templates.continue.button"]
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        let coachMark = app.staticTexts["today.first_completion.coach_mark"].firstMatch
        XCTAssertTrue(coachMark.waitForExistence(timeout: 8))
        let firstToggle = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "habit.toggle.")
        ).firstMatch
        XCTAssertTrue(firstToggle.waitForExistence(timeout: 5))
        firstToggle.tap()
        XCTAssertTrue(coachMark.waitForNonExistence(timeout: 5))

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
    }

    @MainActor
    func testSkippedOnboardingLandsOnUsefulEmptyToday() throws {
        let app = makeOnboardingApp()
        app.launch()

        let skipButton = app.buttons["onboarding.skip.button"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5))
        skipButton.tap()

        XCTAssertTrue(app.buttons["today.add.button"].waitForExistence(timeout: 8))
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "habit.toggle.")).count,
            0
        )
        XCTAssertFalse(app.staticTexts["today.first_completion.coach_mark"].firstMatch.exists)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(springboard.alerts.firstMatch.exists)
    }

    @MainActor
    func testDhikrSupportsCustomPhraseAndThousandTarget() throws {
        let app = makeApp()
        app.launchEnvironment["SUNNAD_UI_TEST_RESET_HABITS"] = "1"
        app.launchEnvironment["SUNNAD_DEBUG_ROOT_SHEET"] = "habit_detail"
        app.launchEnvironment["SUNNAD_DEBUG_HABIT_DETAIL_TYPE"] = "dhikr"
        app.launchEnvironment["SUNNAD_DEBUG_HABIT_DETAIL_MODE"] = "counter"
        app.launch()

        let phrasePicker = app.buttons["dhikr.phrase.picker"]
        XCTAssertTrue(phrasePicker.waitForExistence(timeout: 8))
        phrasePicker.tap()

        let customOption = app.buttons["Custom phrase"]
        XCTAssertTrue(customOption.waitForExistence(timeout: 5))
        customOption.tap()

        let customField = app.textFields["dhikr.custom_phrase.field"]
        XCTAssertTrue(customField.waitForExistence(timeout: 5))
        customField.tap()
        customField.typeText("La ilaha illallah")
        XCTAssertEqual(customField.value as? String, "La ilaha illallah")

        app.scrollViews.firstMatch.swipeUp()
        let thousandPreset = app.buttons["dhikr.target.preset.1000"]
        XCTAssertTrue(thousandPreset.waitForExistence(timeout: 5))
        thousandPreset.tap()
        XCTAssertEqual(app.textFields["dhikr.target.field"].value as? String, "1000")

        XCTAssertTrue(app.buttons["habit.save.button"].isEnabled)
    }

    @MainActor
    func testPhysicalRecipientRegistersForGroupNudges() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["ADAT_PHYSICAL_RELEASE_SMOKE"] == "1" else {
            throw XCTSkip("Physical release smoke test is opt-in")
        }
        let email = environment["ADAT_TEST_EMAIL"]
        let password = environment["ADAT_TEST_PASSWORD"]

        let app = XCUIApplication()
        app.launch()

        let skipButton = app.buttons["onboarding.skip.button"]
        if skipButton.waitForExistence(timeout: 5) {
            skipButton.tap()
        }

        let groupsTab = app.tabBars.buttons["Groups"]
        XCTAssertTrue(groupsTab.waitForExistence(timeout: 8))
        groupsTab.tap()

        let signInButton = app.buttons["Sign In"].firstMatch
        let groupRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "group.row.")
        )

        if signInButton.waitForExistence(timeout: 3) {
            guard let email, let password else {
                XCTFail("Physical smoke credentials are required only when the device has no saved session")
                return
            }
            signInButton.tap()

            let identifierField = app.textFields["auth.identifier.field"]
            let passwordField = app.secureTextFields["auth.password.field"]
            XCTAssertTrue(identifierField.waitForExistence(timeout: 8))
            XCTAssertTrue(passwordField.waitForExistence(timeout: 8))
            identifierField.tap()
            identifierField.typeText(email)
            passwordField.tap()
            passwordField.typeText(password)
            app.buttons["auth.sign_in.button"].tap()
        }

        if !groupRows.firstMatch.waitForExistence(timeout: 15) {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Physical recipient after sign-in"
            screenshot.lifetime = .keepAlways
            add(screenshot)

            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Physical recipient hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(groupRows.firstMatch.exists)

        let groupsScreenshot = XCTAttachment(screenshot: app.screenshot())
        groupsScreenshot.name = "Groups member avatar cluster"
        groupsScreenshot.lifetime = .keepAlways
        add(groupsScreenshot)

        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        app.swipeUp()
        let notificationsButton = app.buttons["Notifications"]
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 8))
        notificationsButton.tap()

        let groupToggle = app.switches["notifications.group_reminders.toggle"]
        XCTAssertTrue(groupToggle.waitForExistence(timeout: 5))
        if (groupToggle.value as? String) != "1" {
            groupToggle.tap()
        }

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let permissionAlert = springboard.alerts.firstMatch
        if permissionAlert.waitForExistence(timeout: 5) {
            let allowButton = permissionAlert.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
            }
        }

        XCTAssertEqual(groupToggle.value as? String, "1")
    }

    @MainActor
    func testReleaseSenderDeliversGroupNudge() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["ADAT_RELEASE_NUDGE_SMOKE"] == "1" else {
            throw XCTSkip("Release nudge smoke test is opt-in")
        }
        guard let email = environment["ADAT_TEST_EMAIL"],
              let password = environment["ADAT_TEST_PASSWORD"] else {
            XCTFail("Nudge smoke credentials are missing")
            return
        }

        let app = XCUIApplication()
        app.launch()
        if app.buttons["onboarding.skip.button"].waitForExistence(timeout: 5) {
            app.buttons["onboarding.skip.button"].tap()
        }

        app.tabBars.buttons["Groups"].tap()
        let signInButton = app.buttons["Sign In"].firstMatch
        XCTAssertTrue(signInButton.waitForExistence(timeout: 8))
        signInButton.tap()

        let identifierField = app.textFields["auth.identifier.field"]
        let passwordField = app.secureTextFields["auth.password.field"]
        XCTAssertTrue(identifierField.waitForExistence(timeout: 8))
        XCTAssertTrue(passwordField.waitForExistence(timeout: 8))
        identifierField.tap()
        identifierField.typeText(email)
        passwordField.tap()
        passwordField.typeText(password)
        app.buttons["auth.sign_in.button"].tap()

        let groupRows = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "group.row.")
        )
        XCTAssertTrue(groupRows.firstMatch.waitForExistence(timeout: 15))
        groupRows.firstMatch.tap()

        let memberRows = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "group.member.row.")
        )
        XCTAssertGreaterThanOrEqual(memberRows.count, 2)

        let reminderButton = app.buttons["groups.reminder.bell"].firstMatch
        for index in 0..<memberRows.count where !reminderButton.exists {
            memberRows.element(boundBy: index).tap()
        }
        XCTAssertTrue(reminderButton.waitForExistence(timeout: 5))
        reminderButton.tap()

        let confirmButton = app.buttons["groups.reminder.send.button"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        let reminderToast = app.descendants(matching: .any)
            .matching(identifier: "groups.reminder.toast")
            .firstMatch
        XCTAssertTrue(reminderToast.waitForExistence(timeout: 15))
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SUNNAD_DEBUG_SKIP_ONBOARDING"] = "1"
        app.launchEnvironment["SUNNAD_DEBUG_LANGUAGE"] = "en"
        app.launchEnvironment["SUNNAD_UI_TEST_RESET_HABITS"] = "1"
        app.launchEnvironment["SUNNAD_UI_TEST_SEED_HABITS"] = "1"
        return app
    }

    private func makeOnboardingApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SUNNAD_DEBUG_LANGUAGE"] = "en"
        app.launchEnvironment["SUNNAD_DEBUG_ONBOARDING_STEP"] = "welcome"
        app.launchEnvironment["SUNNAD_UI_TEST_RESET_HABITS"] = "1"
        return app
    }
}
