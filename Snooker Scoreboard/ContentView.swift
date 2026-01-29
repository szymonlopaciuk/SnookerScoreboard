//
//  ContentView.swift
//  Snooker Scoreboard
//
//  Created by Szymon Łopaciuk on 29/01/2026.
//

import SwiftUI

struct ScoreOption: Identifiable {
    let id = UUID()
    let name: String
    let points: Int
    let colors: [Color]
}

struct ContentView: View {
    @State private var newPlayerName = ""
    @State private var showHistory = false
    @State private var showGameOver = false
    @StateObject private var game = ScoreboardGame()
    @AppStorage("foulAwardPolicy") private var foulAwardPolicyRaw = FoulAwardPolicy.nextPlayer.rawValue
    @AppStorage("enforceSnookerRules") private var enforceSnookerRules = false
    @AppStorage("gameIsActive") private var gameIsActive = false

    private let potOptions: [ScoreOption] = [
        ScoreOption(name: "Red", points: 1, colors: [.red]),
        ScoreOption(name: "Yellow", points: 2, colors: [.yellow]),
        ScoreOption(name: "Green", points: 3, colors: [.green]),
        ScoreOption(name: "Brown", points: 4, colors: [.brown]),
        ScoreOption(name: "Blue", points: 5, colors: [.blue]),
        ScoreOption(name: "Pink", points: 6, colors: [Color(red: 1.0, green: 0.45, blue: 0.7)]),
        ScoreOption(name: "Black", points: 7, colors: [.black])
    ]

    private let foulOptions: [ScoreOption] = [
        ScoreOption(name: "Foul", points: -4, colors: [.white, .red, .yellow, .green, .brown]),
        ScoreOption(name: "Foul on Blue", points: -5, colors: [.blue]),
        ScoreOption(name: "Foul on Pink", points: -6, colors: [Color(red: 1.0, green: 0.45, blue: 0.7)]),
        ScoreOption(name: "Foul on Black", points: -7, colors: [.black])
    ]

    private var hasEnoughPlayers: Bool {
        game.hasEnoughPlayers
    }

    private var leadingScore: Int? {
        game.leadingScore
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 24) {
                playerList
                    .frame(minWidth: 260)

                VStack(alignment: .leading, spacing: 16) {
                    Spacer()
                    if !game.gameStarted {
                        addPlayersCard
                    } else {
                        scoreEntryCard
                    }
                    Spacer()
                }
                .frame(minWidth: 280, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup {
                Button(action: startGame) {
                    Label("Start Game", systemImage: "play.fill")
                }
                    .disabled(game.gameStarted || !hasEnoughPlayers)
                Button(action: resetGame) {
                    Label("New Game", systemImage: "xmark.octagon.fill")
                }
                    .disabled(!game.gameStarted && game.players.isEmpty)
                Button(action: undoLastAction) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                    .disabled(game.actionHistory.isEmpty || !game.gameStarted)
                Button(action: { showHistory = true }) {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            historySheet
        }
        .sheet(isPresented: $showGameOver) {
            gameOverSheet
        }
        .onAppear {
            game.foulAwardPolicy = FoulAwardPolicy(rawValue: foulAwardPolicyRaw) ?? .nextPlayer
            game.enforceRules = enforceSnookerRules
            gameIsActive = game.gameStarted
        }
        .onChange(of: foulAwardPolicyRaw) { newValue in
            game.foulAwardPolicy = FoulAwardPolicy(rawValue: newValue) ?? .nextPlayer
        }
        .onChange(of: enforceSnookerRules) { newValue in
            game.enforceRules = newValue
        }
        .onChange(of: game.gameOver) { newValue in
            if newValue {
                showGameOver = true
            }
        }
        .onChange(of: game.gameStarted) { newValue in
            gameIsActive = newValue
        }
    }

    private var playerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Players")
                .font(.headline)
            List {
                if game.gameStarted {
                    ForEach(Array(game.players.enumerated()), id: \.element.id) { index, player in
                        playerRow(player: player, index: index)
                    }
                } else {
                    ForEach(Array(game.players.enumerated()), id: \.element.id) { index, player in
                        playerRow(player: player, index: index)
                    }
                    .onDelete(perform: deletePlayers)
                }
            }
            .frame(minHeight: 240)
        }
    }

    private func playerRow(player: Player, index: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.headline)
            }
            Spacer()
            HStack(spacing: 6) {
                if !game.gameStarted {
                    Button {
                        game.removePlayer(id: player.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                if game.gameStarted, isLeading(player: player) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                }
                Text("\(player.score)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(game.currentPlayerIndex == index && game.gameStarted ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var addPlayersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Players")
                .font(.headline)
            HStack(spacing: 8) {
                TextField("Player name", text: $newPlayerName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addPlayer)
                Button("Add", action: addPlayer)
                    .disabled(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !hasEnoughPlayers {
                Text("Add at least two players to start.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var scoreEntryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter Score")
                .font(.headline)
            Text("Pot")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                ForEach(potOptions) { option in
                    Button {
                        applyPot(option: option)
                    } label: {
                        HStack {
                            scoreColorDots(colors: option.colors)
                            Text(potLabel(for: option))
                            Spacer()
                            Text("+\(option.points)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isPotDisabled(option: option))
                }
            }
            Text("Foul")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                ForEach(foulOptions) { option in
                    Button {
                        applyFoul(points: option.points)
                    } label: {
                        HStack {
                            scoreColorDots(colors: option.colors)
                            Text(option.name)
                            Spacer()
                            Text("\(option.points)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isFoulDisabled(option: option))
                }
            }
            Spacer()
                .frame(height: 6)
            Button(action: advanceTurn) {
                Label("End Turn", systemImage: "forward.end.fill")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .disabled(!game.gameStarted || game.players.isEmpty)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func isLeading(player: Player) -> Bool {
        guard game.gameStarted, let maxScore = leadingScore else { return false }
        return player.score == maxScore && maxScore > 0
    }

    private func addPlayer() {
        let trimmedName = newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        game.addPlayer(name: trimmedName)
        newPlayerName = ""
    }

    private func deletePlayers(at offsets: IndexSet) {
        game.deletePlayers(at: offsets)
    }

    private func startGame() {
        game.startGame()
    }

    private func resetGame() {
        game.resetGame()
    }

    private func applyPot(option: ScoreOption) {
        let color = option.colors.first ?? .clear
        game.applyPot(ballName: option.name, ballColor: color, points: option.points)
    }

    private func applyFoul(points: Int) {
        game.applyFoul(points: points)
    }

    private func undoLastAction() {
        game.undoLastAction()
    }

    private func advanceTurn() {
        game.advanceTurn()
    }

    private func scoreColorDots(colors: [Color]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var historySheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game History")
                .font(.title2)
            if game.actionHistory.isEmpty {
                Text("No entries yet.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(Array(game.actionHistory.enumerated()), id: \.offset) { index, action in
                        historyRow(index: index, action: action)
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 380, minHeight: 320)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    showHistory = false
                }
            }
        }
    }

    private func historyRow(index: Int, action: ScoreAction) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(index + 1).")
                .foregroundStyle(.secondary)
            switch action.kind {
            case let .pot(playerID, _, ballColor, points):
                Text("\(playerName(for: playerID)) potted")
                Circle()
                    .fill(ballColor)
                    .frame(width: 12, height: 12)
                Text("for \(points) points")
            case let .foul(playerID, points):
                Text("\(playerName(for: playerID)) fouled for \(points) points")
            }
            Spacer()
        }
    }

    private func playerName(for playerID: UUID) -> String {
        game.playerName(for: playerID)
    }

    private func isPotDisabled(option: ScoreOption) -> Bool {
        if !game.gameStarted || game.gameOver { return true }
        if !game.enforceRules { return false }
        return !game.allowedPotNames.contains(option.name)
    }

    private func potLabel(for option: ScoreOption) -> String {
        if game.enforceRules, option.name == "Red" {
            return "Red (\(game.redsRemaining) left)"
        }
        return option.name
    }

    private func isFoulDisabled(option: ScoreOption) -> Bool {
        if !game.gameStarted || game.gameOver { return true }
        if !game.enforceRules { return false }
        guard let ballName = foulBallName(for: option) else { return false }
        return !game.isColorOnTable(ballName)
    }

    private func foulBallName(for option: ScoreOption) -> String? {
        if option.name.hasPrefix("Foul on ") {
            return option.name.replacingOccurrences(of: "Foul on ", with: "")
        }
        return nil
    }

    private var gameOverSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Final Score")
                .font(.title2)
            List {
                ForEach(Array(finalResults.enumerated()), id: \.element.id) { index, player in
                    HStack {
                        if let crownColor = crownColor(for: index) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(crownColor)
                        }
                        Text(player.name)
                        Spacer()
                        Text("\(player.score)")
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 300)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Start New Game") {
                    resetGame()
                    showGameOver = false
                }
            }
        }
    }

    private var finalResults: [Player] {
        game.players.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.name < rhs.name
        }
    }

    private func crownColor(for index: Int) -> Color? {
        switch index {
        case 0:
            return .yellow
        case 1:
            return .gray
        case 2:
            return .brown
        default:
            return nil
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 800, height: 500)
}
