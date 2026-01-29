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

struct ScoreAction {
    let targetDeltas: [UUID: Int]
    let previousCurrentIndex: Int
    let previousRedsRemaining: Int
    let previousRequirement: PotRequirement
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
    @Published var redsRemaining = 15
    @Published var potRequirement: PotRequirement = .red
    @Published var gameOver = false

    var foulAwardPolicy: FoulAwardPolicy = .nextPlayer
    var enforceRules = false

    private let colorSequence = ["Yellow", "Green", "Brown", "Blue", "Pink", "Black"]

    var hasEnoughPlayers: Bool {
        players.count >= 2
    }

    var leadingScore: Int? {
        players.map(\.score).max()
    }

    func addPlayer(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        players.append(Player(name: trimmedName))
    }

    func deletePlayers(at offsets: IndexSet) {
        players.remove(atOffsets: offsets)
    }

    func removePlayer(id: UUID) {
        players.removeAll { $0.id == id }
    }

    func startGame() {
        guard hasEnoughPlayers else { return }
        gameStarted = true
        gameOver = false
        currentPlayerIndex = 0
        actionHistory.removeAll()
        redsRemaining = 15
        potRequirement = .red
        for index in players.indices {
            players[index].score = 0
        }
    }

    func resetGame() {
        gameStarted = false
        gameOver = false
        actionHistory.removeAll()
        currentPlayerIndex = 0
        redsRemaining = 15
        potRequirement = .red
        for index in players.indices {
            players[index].score = 0
        }
    }

    func applyPot(ballName: String, ballColor: Color, points: Int) {
        guard gameStarted, !gameOver, !players.isEmpty else { return }
        if enforceRules, !allowedPotNames.contains(ballName) {
            return
        }
        let previousIndex = currentPlayerIndex
        let targetIndex = currentPlayerIndex
        players[targetIndex].score += points
        let kind = ScoreActionKind.pot(playerID: players[targetIndex].id, ballName: ballName, ballColor: ballColor, points: points)
        let action = ScoreAction(
            targetDeltas: [players[targetIndex].id: points],
            previousCurrentIndex: previousIndex,
            previousRedsRemaining: redsRemaining,
            previousRequirement: potRequirement,
            kind: kind
        )
        actionHistory.append(action)
        updateRequirement(afterPot: ballName)
    }

    func applyFoul(points: Int) {
        guard gameStarted, !gameOver, !players.isEmpty else { return }
        let previousIndex = currentPlayerIndex
        let foulPoints = abs(points)
        let foulingPlayerID = players[currentPlayerIndex].id
        switch foulAwardPolicy {
        case .nextPlayer:
            let nextIndex = (currentPlayerIndex + 1) % players.count
            players[nextIndex].score += foulPoints
            let action = ScoreAction(
                targetDeltas: [players[nextIndex].id: foulPoints],
                previousCurrentIndex: previousIndex,
                previousRedsRemaining: redsRemaining,
                previousRequirement: potRequirement,
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
                previousCurrentIndex: previousIndex,
                previousRedsRemaining: redsRemaining,
                previousRequirement: potRequirement,
                kind: .foul(playerID: foulingPlayerID, points: foulPoints)
            )
            actionHistory.append(action)
        }
        if enforceRules, redsRemaining > 0 {
            potRequirement = .red
        }
        advanceTurn()
    }

    func undoLastAction() {
        guard let lastAction = actionHistory.popLast() else { return }
        for (targetID, delta) in lastAction.targetDeltas {
            if let targetIndex = players.firstIndex(where: { $0.id == targetID }) {
                players[targetIndex].score -= delta
            }
        }
        currentPlayerIndex = min(lastAction.previousCurrentIndex, max(players.count - 1, 0))
        redsRemaining = lastAction.previousRedsRemaining
        potRequirement = lastAction.previousRequirement
        gameOver = false
    }

    func advanceTurn() {
        guard gameStarted, !gameOver, !players.isEmpty else { return }
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        if enforceRules, redsRemaining > 0 {
            potRequirement = .red
        }
    }

    func playerName(for playerID: UUID) -> String {
        players.first(where: { $0.id == playerID })?.name ?? "Unknown"
    }

    var allowedPotNames: Set<String> {
        guard enforceRules else { return [] }
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

    private var availableColorNames: Set<String> {
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
                gameOver = true
                gameStarted = false
            }
        case .red, .color:
            potRequirement = .colorSequence(index: 0)
        }
    }
}
