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

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("UITestMode") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
        }
    }
}

@main
struct Snooker_ScoreboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("foulAwardPolicy") private var foulAwardPolicyRaw = FoulAwardPolicy.nextPlayer.rawValue
    @AppStorage("enforceSnookerRules") private var enforceSnookerRules = false
    @AppStorage("gameIsActive") private var gameIsActive = false
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        WindowGroup("Help", id: "help") {
            HelpView()
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
            CommandGroup(replacing: .help) {
                Button("Snooker Rules") {
                    openWindow(id: "help")
                }
            }
        }
    }
}
