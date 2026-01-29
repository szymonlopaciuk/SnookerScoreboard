//
//  Snooker_ScoreboardTests.swift
//  Snooker ScoreboardTests
//
//  Created by Szymon Łopaciuk on 29/01/2026.
//

import SwiftUI
import Testing
@testable import Snooker_Scoreboard

struct Snooker_ScoreboardTests {

    @Test func potDoesNotAdvanceTurn() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()

        game.applyPot(ballName: "Red", ballColor: .red, points: 1)

        #expect(game.currentPlayerIndex == 0)
        #expect(game.players[0].score == 1)
        #expect(game.players[1].score == 0)
        #expect(game.actionHistory.count == 1)
    }

    @Test func foulAwardsNextPlayerAndAdvancesTurn() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()
        game.foulAwardPolicy = .nextPlayer

        game.applyFoul(points: -4)

        #expect(game.currentPlayerIndex == 1)
        #expect(game.players[0].score == 0)
        #expect(game.players[1].score == 4)
        #expect(game.actionHistory.count == 1)
    }

    @Test func foulAwardsAllPlayers() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()
        game.foulAwardPolicy = .allPlayers

        game.applyFoul(points: -5)

        #expect(game.players[0].score == 5)
        #expect(game.players[1].score == 5)
        #expect(game.currentPlayerIndex == 1)
    }

    @Test func undoRestoresScoresAndTurn() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()

        game.applyPot(ballName: "Blue", ballColor: .blue, points: 5)
        game.undoLastAction()

        #expect(game.players[0].score == 0)
        #expect(game.currentPlayerIndex == 0)
        #expect(game.actionHistory.isEmpty)
    }

}
