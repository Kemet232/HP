import XCTest

final class HPUITests: XCTestCase {
    private func launch(_ scenario: String = "normal", onboarding: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--hp-ui-testing", "--hp-scenario=\(scenario)"] + (onboarding ? ["--hp-onboarding"] : [])
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        return app
    }
    func testOnboardingWithoutHealthData() {
        let app = launch("missing", onboarding: true)
        app.buttons["getStarted"].tap()
        app.buttons["continueGoal"].tap()
        app.buttons["finishOnboarding"].tap()
        XCTAssertTrue(app.buttons["calorieBalance"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["calorieBalance"].label, "Calorie balance unavailable")
    }
    func testWhyAndNegativeBalance() {
        let app = launch("over")
        XCTAssertEqual(app.buttons["calorieBalance"].label, "-241 kilocalories remaining today")
        app.buttons["calorieBalance"].tap()
        XCTAssertTrue(app.staticTexts["Resting energy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Goal adjustment"].exists)
    }
    func testSettingsGoalChangeRecalculates() {
        let app = launch()
        app.buttons["settings"].tap()
        app.buttons["Maintain"].tap()
        app.buttons["saveSettings"].tap()
        XCTAssertEqual(app.buttons["calorieBalance"].label, "\(1247.formatted()) kilocalories remaining today")
    }
    func testUnknownAccessDoesNotShowZero() {
        let app = launch("read-unavailable")
        XCTAssertEqual(app.buttons["calorieBalance"].label, "Calorie balance unavailable")
        XCTAssertTrue(app.staticTexts["A little more data is needed"].exists)
    }
    func testAccessibilitySizeCanOpenCalculation() {
        let app = launch(largeText: true)
        XCTAssertTrue(app.buttons["calorieBalance"].exists)
        app.buttons["calorieBalance"].tap()
        XCTAssertTrue(app.staticTexts["Resting energy"].waitForExistence(timeout: 5))
    }

}
