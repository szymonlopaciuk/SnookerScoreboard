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

struct ScoreAction {
    let targetDeltas: [UUID: Int]
    let previousCurrentIndex: Int
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

    var foulAwardPolicy: FoulAwardPolicy = .nextPlayer

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

    func startGame() {
        guard hasEnoughPlayers else { return }
        gameStarted = true
        currentPlayerIndex = 0
        actionHistory.removeAll()
        for index in players.indices {
            players[index].score = 0
        }
    }

    func resetGame() {
        gameStarted = false
        actionHistory.removeAll()
        currentPlayerIndex = 0
        for index in players.indices {
            players[index].score = 0
        }
    }

    func applyPot(ballName: String, ballColor: Color, points: Int) {
        guard gameStarted, !players.isEmpty else { return }
        let previousIndex = currentPlayerIndex
        let targetIndex = currentPlayerIndex
        players[targetIndex].score += points
        let kind = ScoreActionKind.pot(playerID: players[targetIndex].id, ballName: ballName, ballColor: ballColor, points: points)
        actionHistory.append(ScoreAction(targetDeltas: [players[targetIndex].id: points], previousCurrentIndex: previousIndex, kind: kind))
    }

    func applyFoul(points: Int) {
        guard gameStarted, !players.isEmpty else { return }
        let previousIndex = currentPlayerIndex
        let foulPoints = abs(points)
        let foulingPlayerID = players[currentPlayerIndex].id
        switch foulAwardPolicy {
        case .nextPlayer:
            let nextIndex = (currentPlayerIndex + 1) % players.count
            players[nextIndex].score += foulPoints
            actionHistory.append(ScoreAction(targetDeltas: [players[nextIndex].id: foulPoints], previousCurrentIndex: previousIndex, kind: .foul(playerID: foulingPlayerID, points: foulPoints)))
        case .allPlayers:
            for index in players.indices {
                players[index].score += foulPoints
            }
            let targetDeltas = Dictionary(uniqueKeysWithValues: players.map { ($0.id, foulPoints) })
            actionHistory.append(ScoreAction(targetDeltas: targetDeltas, previousCurrentIndex: previousIndex, kind: .foul(playerID: foulingPlayerID, points: foulPoints)))
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
    }

    func advanceTurn() {
        guard gameStarted, !players.isEmpty else { return }
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
    }

    func playerName(for playerID: UUID) -> String {
        players.first(where: { $0.id == playerID })?.name ?? "Unknown"
    }
}
