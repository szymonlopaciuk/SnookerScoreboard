//
//  HelpView.swift
//  Snooker Scoreboard
//
//  Created by Szymon Łopaciuk on 29/01/2026.
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Snooker Rules (Quick Reference)")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Standard Rules (Simplified)")
                        .font(.headline)
                    HStack(spacing: 6) {
                        Text("• A frame starts with 15 reds")
                        colorDot(.red)
                        Text("and six colors.")
                    }
                    Text("• You must pot a red first, then a color, alternating while reds remain.")
                    colorSequenceRow
                    Text("• If scores are tied after the final black, the black is respotted and play continues.")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Fouls and Snookers")
                        .font(.headline)
                    Text("• A foul scores at least 4 points, or the value of the ball involved, whichever is higher (up to 7).")
                    Text("• Common fouls: hitting the wrong ball first, potting the cue ball, or failing to hit any ball.")
                    Text("• Being snookered means the cue ball cannot see the full target ball on any direct line.")
                    Text("• If snookered and you miss the target ball, a miss may be called and the foul points still apply before a replay.")
                    Text("• In the Game menu, you can choose who receives foul points (next player or all players).")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Glossary")
                        .font(.headline)
                    Text("• Free ball: awarded after a foul when you are snookered; any ball can be nominated as a red.")
                    Text("• Call: to nominate the intended ball, pocket, or shot outcome, depending on house rules.")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private var colorSequenceRow: some View {
        HStack(spacing: 6) {
            Text("• After the last red is potted, colors are potted in order:")
            colorDot(.yellow)
            Text("Yellow,")
            colorDot(.green)
            Text("Green,")
            colorDot(.brown)
            Text("Brown,")
            colorDot(.blue)
            Text("Blue,")
            colorDot(Color(red: 1.0, green: 0.45, blue: 0.7))
            Text("Pink,")
            colorDot(.black)
            Text("Black.")
        }
    }


    private func colorDot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }
}

#Preview {
    HelpView()
}
