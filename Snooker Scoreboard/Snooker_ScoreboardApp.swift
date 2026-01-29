//
//  Snooker_ScoreboardApp.swift
//  Snooker Scoreboard
//
//  Created by Szymon Łopaciuk on 29/01/2026.
//

import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct Snooker_ScoreboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("foulAwardPolicy") private var foulAwardPolicyRaw = FoulAwardPolicy.nextPlayer.rawValue
    @AppStorage("enforceSnookerRules") private var enforceSnookerRules = false
    @AppStorage("gameIsActive") private var gameIsActive = false

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Game") {
                Picker("Foul Points Awarded To", selection: $foulAwardPolicyRaw) {
                    ForEach(FoulAwardPolicy.allCases) { policy in
                        Text(policy.title)
                            .tag(policy.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .disabled(gameIsActive)
                Divider()
                Toggle("Enforce Snooker Rules", isOn: $enforceSnookerRules)
                    .disabled(gameIsActive)
            }
        }
    }
}
