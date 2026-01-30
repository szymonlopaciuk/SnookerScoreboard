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
        app.launch()

        XCTAssertTrue(app.buttons["start-game-button"].waitForExistence(timeout: 8))

        addPlayer(named: "John", in: app)
        addPlayer(named: "Anna", in: app)

        app.buttons["start-game-button"].firstMatch.click()

        let endGame = app.buttons["end-game-button"].firstMatch
        XCTAssertTrue(endGame.waitForExistence(timeout: 2))
        endGame.click()

        let finalScoreTitle = app.staticTexts["final-score-title"]
        XCTAssertTrue(finalScoreTitle.waitForExistence(timeout: 3))
        XCTAssertTrue(app.images["final-crown-gold-John"].exists)
        XCTAssertTrue(app.images["final-crown-gold-Anna"].exists)
        XCTAssertFalse(app.images["final-crown-silver-John"].exists)
        XCTAssertFalse(app.images["final-crown-bronze-John"].exists)
        XCTAssertTrue(app.buttons["final-start-new-game"].exists)
    }

    @MainActor
    private func addPlayer(named name: String, in app: XCUIApplication) {
        let nameField = app.textFields["player-name-field"]
        nameField.click()
        nameField.typeText(name)
        app.buttons["add-player-button"].click()
    }
}
