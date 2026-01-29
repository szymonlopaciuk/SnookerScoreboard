//
//  Snooker_ScoreboardUITests.swift
//  Snooker ScoreboardUITests
//
//  Created by Szymon Łopaciuk on 29/01/2026.
//

import XCTest

final class Snooker_ScoreboardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testFinalScoreDialogShowsSharedGoldCrownsOnTie() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITestEnforceRules", "UITestShortGame"]
        app.launch()

        addPlayer(named: "John", in: app)
        addPlayer(named: "Anna", in: app)

        app.buttons["start-game-button"].click()

        let foulOnBlack = app.buttons["foul-black"]
        XCTAssertTrue(foulOnBlack.waitForExistence(timeout: 2))
        foulOnBlack.click()

        let endTurn = app.buttons["end-turn-button"]
        XCTAssertTrue(endTurn.waitForExistence(timeout: 2))
        endTurn.click()

        let potBlack = app.buttons["pot-black"]
        XCTAssertTrue(potBlack.waitForExistence(timeout: 2))
        potBlack.click()

        let finalSheet = app.otherElements["final-score-sheet"]
        XCTAssertTrue(finalSheet.waitForExistence(timeout: 2))
        XCTAssertTrue(app.images["final-crown-gold-John"].exists)
        XCTAssertTrue(app.images["final-crown-gold-Anna"].exists)
        XCTAssertFalse(app.images["final-crown-silver-John"].exists)
        XCTAssertFalse(app.images["final-crown-bronze-John"].exists)
        XCTAssertTrue(app.buttons["final-start-new-game"].exists)
    }

    @MainActor
    private func addPlayer(named name: String, in app: XCUIApplication) {
        let nameField = app.textFields["player-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.click()
        nameField.typeText(name)
        app.buttons["add-player-button"].click()
    }
}
