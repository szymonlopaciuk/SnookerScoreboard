//
//  ScoreboardGame.swift
//  Snooker Scoreboard
//
//  Created by Szymon Łopaciuk on 29/01/2026.
//

import Foundation
import SwiftUI

struct Player: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var score: Int = 0
}

enum ScoreActionKind {
    case pot(playerID: UUID, ballName: String, ballColor: Color, points: Int)
    case foul(playerID: UUID, points: Int)
}

enum PotRequirement: Equatable {
    case red
    case color
    case colorSequence(index: Int)
}

struct FreeBallOption {
    let name: String
    let points: Int
    let color: Color
    let countsAsRed: Bool
}

struct BallOnInfo {
    let name: String
    let points: Int
    let color: Color
    let offTableRemovesBall: Bool
}

struct ScoreAction {
    let targetDeltas: [UUID: Int]
    let foulDeltas: [UUID: Int]
    let previousCurrentIndex: Int
    let previousRedsRemaining: Int
    let previousRequirement: PotRequirement
    let previousCurrentBreaks: [UUID: Int]
    let previousHighestBreaks: [UUID: Int]
    let kind: ScoreActionKind
}

enum FoulAwardPolicy: String, CaseIterable, Identifiable {
    case nextPlayer
    case allPlayers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nextPlayer:
            return "Next Player"
        case .allPlayers:
            return "All Players"
        }
    }
}

final class ScoreboardGame: ObservableObject {
    @Published var players: [Player] = []
    @Published var gameStarted = false
    @Published var currentPlayerIndex = 0
    @Published var actionHistory: [ScoreAction] = []
    @Published var foulCounts: [UUID: Int] = [:]
    @Published var currentBreaks: [UUID: Int] = [:]
    @Published var highestBreaks: [UUID: Int] = [:]
    @Published var redsRemaining = 15
    @Published var potRequirement: PotRequirement = .red
    @Published var gameOver = false
    @Published var respottedBlackActive = false
    @Published var foulCarryoverActive = false
    @Published var turnHasAction = false

    var foulAwardPolicy: FoulAwardPolicy = .nextPlayer
    var enforceRules = false

    private let colorSequence = ["Yellow", "Green", "Brown", "Blue", "Pink", "Black"]
    private let colorValues: [String: Int] = [
        "Yellow": 2,
        "Green": 3,
        "Brown": 4,
        "Blue": 5,
        "Pink": 6,
        "Black": 7,
        "Red": 1
    ]

    var hasEnoughPlayers: Bool {
        players.count >= 2
    }

    var leadingScore: Int? {
        players.map(\.score).max()
    }

    func addPlayer(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let player = Player(name: trimmedName)
        players.append(player)
        foulCounts[player.id] = 0
        currentBreaks[player.id] = 0
        highestBreaks[player.id] = 0
    }

    func deletePlayers(at offsets: IndexSet) {
        for index in offsets {
            let id = players[index].id
            foulCounts[id] = nil
            currentBreaks[id] = nil
            highestBreaks[id] = nil
        }
        players.remove(atOffsets: offsets)
    }

    func removePlayer(id: UUID) {
        players.removeAll { $0.id == id }
        foulCounts[id] = nil
        currentBreaks[id] = nil
        highestBreaks[id] = nil
    }

    func startGame() {
        guard hasEnoughPlayers else { return }
        gameStarted = true
        gameOver = false
        respottedBlackActive = false
        foulCarryoverActive = false
        turnHasAction = false
        currentPlayerIndex = 0
        actionHistory.removeAll()
        foulCounts = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })
        currentBreaks = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })
        highestBreaks = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })
        redsRemaining = 15
        potRequirement = .red
        if ProcessInfo.processInfo.arguments.contains("UITestShortGame") {
            redsRemaining = 0
            potRequirement = .colorSequence(index: 5)
        }
        for index in players.indices {
            players[index].score = 0
        }
    }

    func resetGame() {
        gameStarted = false
        gameOver = false
        respottedBlackActive = false
        foulCarryoverActive = false
        turnHasAction = false
        actionHistory.removeAll()
        currentPlayerIndex = 0
        foulCounts = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })
        currentBreaks = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })
        highestBreaks = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })
        redsRemaining = 15
        potRequirement = .red
        for index in players.indices {
            players[index].score = 0
        }
    }

    func endGame() {
        guard gameStarted else { return }
        gameStarted = false
        gameOver = true
        respottedBlackActive = false
        foulCarryoverActive = false
        turnHasAction = false
    }

    func applyPot(ballName: String, ballColor: Color, points: Int) {
        guard gameStarted, !gameOver, !players.isEmpty else { return }
        if enforceRules, !allowedPotNames.contains(ballName) {
            return
        }
        turnHasAction = true
        foulCarryoverActive = false
        let previousIndex = currentPlayerIndex
        let targetIndex = currentPlayerIndex
        let targetID = players[targetIndex].id
        players[targetIndex].score += points
        let previousCurrentBreak = currentBreaks[targetID, default: 0]
        let previousHighestBreak = highestBreaks[targetID, default: 0]
        let newCurrentBreak = previousCurrentBreak + points
        currentBreaks[targetID] = newCurrentBreak
        if newCurrentBreak > previousHighestBreak {
            highestBreaks[targetID] = newCurrentBreak
        }
        let kind = ScoreActionKind.pot(playerID: players[targetIndex].id, ballName: ballName, ballColor: ballColor, points: points)
        let action = ScoreAction(
            targetDeltas: [players[targetIndex].id: points],
            foulDeltas: [:],
            previousCurrentIndex: previousIndex,
            previousRedsRemaining: redsRemaining,
            previousRequirement: potRequirement,
            previousCurrentBreaks: [targetID: previousCurrentBreak],
            previousHighestBreaks: [targetID: previousHighestBreak],
            kind: kind
        )
        actionHistory.append(action)
        updateRequirement(afterPot: ballName)
    }

    func applyFreeBall(option: FreeBallOption) {
        guard gameStarted, !gameOver, !players.isEmpty else { return }
        guard canUseFreeBall else { return }
        turnHasAction = true
        foulCarryoverActive = false
        let previousIndex = currentPlayerIndex
        let targetIndex = currentPlayerIndex
        let targetID = players[targetIndex].id
        players[targetIndex].score += option.points
        let previousCurrentBreak = currentBreaks[targetID, default: 0]
        let previousHighestBreak = highestBreaks[targetID, default: 0]
        let newCurrentBreak = previousCurrentBreak + option.points
        currentBreaks[targetID] = newCurrentBreak
        if newCurrentBreak > previousHighestBreak {
            highestBreaks[targetID] = newCurrentBreak
        }
        let kind = ScoreActionKind.pot(playerID: targetID, ballName: option.name, ballColor: option.color, points: option.points)
        let action = ScoreAction(
            targetDeltas: [targetID: option.points],
            foulDeltas: [:],
            previousCurrentIndex: previousIndex,
            previousRedsRemaining: redsRemaining,
            previousRequirement: potRequirement,
            previousCurrentBreaks: [targetID: previousCurrentBreak],
            previousHighestBreaks: [targetID: previousHighestBreak],
            kind: kind
        )
        actionHistory.append(action)
        if option.countsAsRed, redsRemaining > 0 {
            potRequirement = .color
        } else {
            updateRequirement(afterPot: option.name)
        }
    }

    func applyFoul(points: Int) {
        guard gameStarted, !gameOver, !players.isEmpty else { return }
        let previousIndex = currentPlayerIndex
        let foulPoints = abs(points)
        let foulingPlayerID = players[currentPlayerIndex].id
        foulCounts[foulingPlayerID, default: 0] += 1
        let previousCurrentBreak = currentBreaks[foulingPlayerID, default: 0]
        let previousHighestBreak = highestBreaks[foulingPlayerID, default: 0]
        currentBreaks[foulingPlayerID] = 0
        let foulDelta = [foulingPlayerID: 1]
        switch foulAwardPolicy {
        case .nextPlayer:
            let nextIndex = (currentPlayerIndex + 1) % players.count
            players[nextIndex].score += foulPoints
            let action = ScoreAction(
                targetDeltas: [players[nextIndex].id: foulPoints],
                foulDeltas: foulDelta,
                previousCurrentIndex: previousIndex,
                previousRedsRemaining: redsRemaining,
                previousRequirement: potRequirement,
                previousCurrentBreaks: [foulingPlayerID: previousCurrentBreak],
                previousHighestBreaks: [foulingPlayerID: previousHighestBreak],
                kind: .foul(playerID: foulingPlayerID, points: foulPoints)
            )
            actionHistory.append(action)
        case .allPlayers:
            for index in players.indices {
                players[index].score += foulPoints
            }
            let targetDeltas = Dictionary(uniqueKeysWithValues: players.map { ($0.id, foulPoints) })
            let action = ScoreAction(
                targetDeltas: targetDeltas,
                foulDeltas: foulDelta,
                previousCurrentIndex: previousIndex,
                previousRedsRemaining: redsRemaining,
                previousRequirement: potRequirement,
                previousCurrentBreaks: [foulingPlayerID: previousCurrentBreak],
                previousHighestBreaks: [foulingPlayerID: previousHighestBreak],
                kind: .foul(playerID: foulingPlayerID, points: foulPoints)
            )
            actionHistory.append(action)
        }
        advanceTurn(carryFoul: true)
    }

    func undoLastAction() {
        guard let lastAction = actionHistory.popLast() else { return }
        for (targetID, delta) in lastAction.targetDeltas {
            if let targetIndex = players.firstIndex(where: { $0.id == targetID }) {
                players[targetIndex].score -= delta
            }
        }
        for (targetID, delta) in lastAction.foulDeltas {
            foulCounts[targetID, default: 0] -= delta
        }
        for (targetID, value) in lastAction.previousCurrentBreaks {
            currentBreaks[targetID] = value
        }
        for (targetID, value) in lastAction.previousHighestBreaks {
            highestBreaks[targetID] = value
        }
        currentPlayerIndex = min(lastAction.previousCurrentIndex, max(players.count - 1, 0))
        redsRemaining = lastAction.previousRedsRemaining
        potRequirement = lastAction.previousRequirement
        gameOver = false
        respottedBlackActive = false
        foulCarryoverActive = false
        turnHasAction = false
    }

    func advanceTurn() {
        advanceTurn(carryFoul: false)
    }

    func playerName(for playerID: UUID) -> String {
        players.first(where: { $0.id == playerID })?.name ?? "Unknown"
    }

    func foulCount(for playerID: UUID) -> Int {
        foulCounts[playerID, default: 0]
    }

    func highestBreak(for playerID: UUID) -> Int {
        highestBreaks[playerID, default: 0]
    }

    var canUseFreeBall: Bool {
        enforceRules && foulCarryoverActive && !turnHasAction && currentBallOn != nil
    }

    var canUseReplay: Bool {
        foulCarryoverActive && !turnHasAction && gameStarted && !gameOver
    }

    var canUseOffTableFoul: Bool {
        guard gameStarted, !gameOver, enforceRules else { return false }
        return currentBallOn?.offTableRemovesBall == true
    }

    func replayPreviousTurn() {
        guard canUseReplay else { return }
        let previousIndex = (currentPlayerIndex - 1 + players.count) % players.count
        currentPlayerIndex = previousIndex
        foulCarryoverActive = false
        turnHasAction = false
    }

    func applyOffTableFoul() {
        guard let ballOn = currentBallOn, canUseOffTableFoul else { return }
        var finishedColors = false

        if redsRemaining > 0, ballOn.name == "Red" {
            let nextReds = max(redsRemaining - 1, 0)
            redsRemaining = nextReds
            potRequirement = nextReds == 0 ? .colorSequence(index: 0) : .red
        } else if case let .colorSequence(index) = potRequirement, redsRemaining == 0 {
            let nextIndex = index + 1
            potRequirement = .colorSequence(index: nextIndex)
            finishedColors = nextIndex >= colorSequence.count
        } else if respottedBlackActive, ballOn.name == "Black" {
            finishedColors = true
        }

        let foulPoints = max(4, ballOn.points)
        applyFoul(points: -foulPoints)

        if finishedColors {
            if isTieForLead {
                respottedBlackActive = true
                potRequirement = .colorSequence(index: 5)
                gameOver = false
                gameStarted = true
            } else {
                gameOver = true
                gameStarted = false
                respottedBlackActive = false
            }
        }
    }

    var allowedPotNames: Set<String> {
        guard enforceRules else { return [] }
        if respottedBlackActive {
            return ["Black"]
        }
        if redsRemaining > 0 {
            switch potRequirement {
            case .red:
                return ["Red"]
            case .color:
                return Set(colorSequence)
            case .colorSequence:
                return Set(colorSequence)
            }
        }
        switch potRequirement {
        case let .colorSequence(index):
            if colorSequence.indices.contains(index) {
                return [colorSequence[index]]
            }
            return []
        case .red:
            return []
        case .color:
            return Set(colorSequence)
        }
    }

    func isColorOnTable(_ name: String) -> Bool {
        availableColorNames.contains(name)
    }

    var freeBallOption: FreeBallOption? {
        guard gameStarted, !gameOver else { return nil }
        guard canUseFreeBall, let ballOn = currentBallOn else { return nil }
        let countsAsRed = redsRemaining > 0
        return FreeBallOption(name: ballOn.name, points: ballOn.points, color: ballOn.color, countsAsRed: countsAsRed)
    }

    private var availableColorNames: Set<String> {
        if respottedBlackActive {
            return ["Black"]
        }
        if redsRemaining > 0 {
            return Set(colorSequence + ["Red"])
        }
        switch potRequirement {
        case let .colorSequence(index):
            if colorSequence.indices.contains(index) {
                return Set(colorSequence[index...])
            }
            return []
        case .red, .color:
            return Set(colorSequence)
        }
    }

    private func updateRequirement(afterPot ballName: String) {
        if redsRemaining > 0 {
            if ballName == "Red" {
                redsRemaining = max(redsRemaining - 1, 0)
                if redsRemaining == 0 {
                    potRequirement = .colorSequence(index: 0)
                } else {
                    potRequirement = .color
                }
            } else {
                potRequirement = .red
            }
            return
        }

        switch potRequirement {
        case let .colorSequence(index):
            let nextIndex = index + 1
            potRequirement = .colorSequence(index: nextIndex)
            if enforceRules, nextIndex >= colorSequence.count {
                if isTieForLead {
                    respottedBlackActive = true
                    potRequirement = .colorSequence(index: 5)
                } else {
                    gameOver = true
                    gameStarted = false
                    respottedBlackActive = false
                }
            }
        case .red, .color:
            potRequirement = .colorSequence(index: 0)
        }
    }

    private func advanceTurn(carryFoul: Bool) {
        guard gameStarted, !gameOver, !players.isEmpty else { return }
        let currentPlayerID = players[currentPlayerIndex].id
        currentBreaks[currentPlayerID] = 0
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        if enforceRules, redsRemaining > 0, !respottedBlackActive {
            potRequirement = .red
        }
        foulCarryoverActive = carryFoul
        turnHasAction = false
    }

    var currentBallOn: BallOnInfo? {
        if respottedBlackActive {
            return BallOnInfo(name: "Black", points: 7, color: .black, offTableRemovesBall: true)
        }
        if redsRemaining > 0 {
            if potRequirement == .red {
                return BallOnInfo(name: "Red", points: 1, color: .red, offTableRemovesBall: true)
            }
            return nil
        }
        if case let .colorSequence(index) = potRequirement, colorSequence.indices.contains(index) {
            let name = colorSequence[index]
            let points = colorValues[name] ?? 0
            let color = colorForName(name)
            return BallOnInfo(name: name, points: points, color: color, offTableRemovesBall: true)
        }
        return nil
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "Yellow":
            return .yellow
        case "Green":
            return .green
        case "Brown":
            return .brown
        case "Blue":
            return .blue
        case "Pink":
            return Color(red: 1.0, green: 0.45, blue: 0.7)
        case "Black":
            return .black
        case "Red":
            return .red
        default:
            return .gray
        }
    }

    private var isTieForLead: Bool {
        guard let maxScore = players.map(\.score).max() else { return false }
        return players.filter { $0.score == maxScore }.count > 1
    }
}
