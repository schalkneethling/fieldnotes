import XCTest

final class FieldnotesUITests: XCTestCase {
    private var storeIdentifier: UUID!

    override func setUpWithError() throws {
        continueAfterFailure = false
        storeIdentifier = UUID()
    }

    override func tearDownWithError() throws {
        storeIdentifier = nil
    }

    func testCapturePersistsAcrossRelaunchAndDeletionRequiresConfirmation() {
        let note = "UI persistence \(UUID().uuidString)"
        let app = makeApp()

        app.launch()
        capture(note, in: app)
        openReview(in: app)
        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openReview(in: app)

        let persistedNote = app.staticTexts[note]
        XCTAssertTrue(persistedNote.waitForExistence(timeout: 5))

        revealDeleteAction(for: persistedNote, in: app)
        app.buttons["Delete Fieldnote"].tap()

        let confirmation = app.alerts["Delete this Fieldnote?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(persistedNote.exists)

        revealDeleteAction(for: persistedNote, in: app)
        app.buttons["Delete Fieldnote"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.buttons["Delete"].tap()
        XCTAssertTrue(persistedNote.waitForNonExistence(timeout: 5))

        app.terminate()
        app.launch()
        openReview(in: app)
        XCTAssertFalse(app.staticTexts[note].waitForExistence(timeout: 2))
    }

    func testSaveFailureRetainsDraftAndRetrySucceeds() {
        let note = "Retry save \(UUID().uuidString)"
        let app = makeApp(failFirstSave: true)

        app.launch()
        enterDraft(note, in: app)
        app.buttons["Save"].tap()

        let failureAlert = app.alerts["Fieldnote wasn’t saved"]
        XCTAssertTrue(failureAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(failureAlert.staticTexts["Your draft is still here. Check available storage and try again."].exists)
        failureAlert.buttons["OK"].tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.exists)
        XCTAssertEqual(editor.value as? String, note)

        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Capture fieldnote"].waitForExistence(timeout: 5))
        openReview(in: app)
        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 5))
    }

    func testStoreOpenFailurePresentsRecoveryAndRetryOpensStore() {
        let app = makeApp(failFirstStoreOpen: true)

        app.launch()

        XCTAssertTrue(
            app.staticTexts["Fieldnotes couldn’t open your notes"]
                .waitForExistence(timeout: 5)
        )
        let retryButton = app.buttons["Try Again"]
        XCTAssertTrue(retryButton.exists)
        retryButton.tap()

        XCTAssertTrue(app.buttons["Capture fieldnote"].waitForExistence(timeout: 5))
    }

    private func capture(_ note: String, in app: XCUIApplication) {
        enterDraft(note, in: app)

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        let captureButton = app.buttons["Capture fieldnote"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5))
    }

    private func enterDraft(_ note: String, in app: XCUIApplication) {
        let captureButton = app.buttons["Capture fieldnote"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5))
        captureButton.tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.tap()
        editor.typeText(note)

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.isEnabled)
    }

    private func openReview(in app: XCUIApplication) {
        let reviewButton = app.buttons["Review"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 5))
        reviewButton.tap()
        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 2))
    }

    private func revealDeleteAction(
        for note: XCUIElement,
        in app: XCUIApplication
    ) {
        note.swipeLeft()
        XCTAssertTrue(app.buttons["Delete Fieldnote"].waitForExistence(timeout: 2))
    }

    private func makeApp(
        failFirstSave: Bool = false,
        failFirstStoreOpen: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["FIELDNOTES_UI_TEST_STORE_IDENTIFIER"] = storeIdentifier.uuidString
        if failFirstSave {
            app.launchEnvironment["FIELDNOTES_UI_TEST_FAIL_FIRST_SAVE"] = "1"
        }
        if failFirstStoreOpen {
            app.launchEnvironment["FIELDNOTES_UI_TEST_FAIL_FIRST_STORE_OPEN"] = "1"
        }
        return app
    }
}
