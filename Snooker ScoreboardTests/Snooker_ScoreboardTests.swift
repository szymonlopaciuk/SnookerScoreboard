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
        #expect(game.highestBreak(for: game.players[0].id) == 1)
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
        #expect(game.foulCount(for: game.players[0].id) == 1)
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
        game.applyFoul(points: -4)
        game.undoLastAction()

        #expect(game.players[0].score == 0)
        #expect(game.currentPlayerIndex == 0)
        #expect(game.foulCount(for: game.players[0].id) == 0)
        #expect(game.highestBreak(for: game.players[0].id) == 5)
        #expect(game.actionHistory.isEmpty)
    }

    @Test func highestBreakResetsOnEndTurn() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()

        game.applyPot(ballName: "Red", ballColor: .red, points: 1)
        game.applyPot(ballName: "Black", ballColor: .black, points: 7)
        game.advanceTurn()
        game.applyPot(ballName: "Red", ballColor: .red, points: 1)

        #expect(game.highestBreak(for: game.players[0].id) == 8)
        #expect(game.currentBreaks[game.players[0].id] == 0)
    }

    @Test func foulResetsCurrentBreakButKeepsHighest() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()

        game.applyPot(ballName: "Red", ballColor: .red, points: 1)
        game.applyPot(ballName: "Black", ballColor: .black, points: 7)
        game.applyFoul(points: -4)

        #expect(game.highestBreak(for: game.players[0].id) == 8)
        #expect(game.currentBreaks[game.players[0].id] == 0)
        #expect(game.foulCount(for: game.players[0].id) == 1)
    }

    @Test func undoFoulRestoresBreakAndHighest() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()

        game.applyPot(ballName: "Red", ballColor: .red, points: 1)
        game.applyPot(ballName: "Black", ballColor: .black, points: 7)
        game.applyFoul(points: -4)
        game.undoLastAction()

        #expect(game.highestBreak(for: game.players[0].id) == 8)
        #expect(game.currentBreaks[game.players[0].id] == 8)
        #expect(game.foulCount(for: game.players[0].id) == 0)
    }

    @Test func enforceRulesBlocksInvalidPots() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()
        game.enforceRules = true

        game.applyPot(ballName: "Blue", ballColor: .blue, points: 5)

        #expect(game.players[0].score == 0)
        #expect(game.actionHistory.isEmpty)
        #expect(game.redsRemaining == 15)
    }

    @Test func enforceRulesAlternatesRedAndColor() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()
        game.enforceRules = true

        game.applyPot(ballName: "Red", ballColor: .red, points: 1)
        game.applyPot(ballName: "Blue", ballColor: .blue, points: 5)

        #expect(game.players[0].score == 6)
        #expect(game.redsRemaining == 14)
        #expect(game.potRequirement == .red)
    }

    @Test func enforceRulesRunsColorSequenceAfterReds() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()
        game.enforceRules = true
        game.redsRemaining = 1
        game.potRequirement = .red

        game.applyPot(ballName: "Red", ballColor: .red, points: 1)
        game.applyPot(ballName: "Yellow", ballColor: .yellow, points: 2)

        #expect(game.redsRemaining == 0)
        #expect(game.potRequirement == .colorSequence(index: 1))
    }

    @Test func removePlayerRemovesBeforeStart() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")

        game.removePlayer(id: game.players[0].id)

        #expect(game.players.count == 1)
        #expect(game.players.first?.name == "Anna")
    }

    @Test func gameEndsAfterFinalBlackInSequence() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()
        game.enforceRules = true
        game.redsRemaining = 0
        game.potRequirement = .colorSequence(index: 5)

        game.applyPot(ballName: "Black", ballColor: .black, points: 7)

        #expect(game.gameOver)
        #expect(!game.gameStarted)
    }

    @Test func availableColorsShrinkAfterSequenceStarts() async throws {
        let game = ScoreboardGame()
        game.addPlayer(name: "John")
        game.addPlayer(name: "Anna")
        game.startGame()
        game.enforceRules = true
        game.redsRemaining = 0
        game.potRequirement = .colorSequence(index: 2)

        #expect(!game.isColorOnTable("Yellow"))
        #expect(!game.isColorOnTable("Green"))
        #expect(game.isColorOnTable("Brown"))
        #expect(game.isColorOnTable("Black"))
    }

}
