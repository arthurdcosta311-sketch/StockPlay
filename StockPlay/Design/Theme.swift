//
//  Theme.swift
//  StockPlay
//
//  One palette for the whole app: charcoal, ivory and a restrained gold.
//

import SwiftUI

enum Theme {
    static let background = Color(red: 0.043, green: 0.047, blue: 0.059)
    static let surface = Color(red: 0.086, green: 0.090, blue: 0.106)
    static let surfaceRaised = Color(red: 0.129, green: 0.137, blue: 0.157)
    static let hairline = Color.white.opacity(0.08)

    static let gold = Color(red: 0.804, green: 0.643, blue: 0.353)
    static let ivory = Color(red: 0.957, green: 0.925, blue: 0.863)
    static let ink = Color(red: 0.094, green: 0.106, blue: 0.125)

    static let textPrimary = Color(red: 0.949, green: 0.945, blue: 0.933)
    static let textSecondary = Color(red: 0.604, green: 0.616, blue: 0.639)

    static let squareLight = Color(red: 0.918, green: 0.878, blue: 0.792)
    static let squareDark = Color(red: 0.353, green: 0.404, blue: 0.459)

    static let win = Color(red: 0.541, green: 0.769, blue: 0.518)
    static let loss = Color(red: 0.851, green: 0.451, blue: 0.427)

    // Move verdicts, the way chess.com colours them.
    static let brilliant = Color(red: 0.149, green: 0.741, blue: 0.647)
    static let best = Color(red: 0.506, green: 0.714, blue: 0.298)
    static let good = Color(red: 0.596, green: 0.729, blue: 0.404)
    static let book = Color(red: 0.710, green: 0.545, blue: 0.400)
    static let inaccuracy = Color(red: 0.969, green: 0.776, blue: 0.192)
    static let mistake = Color(red: 1.000, green: 0.643, blue: 0.349)
    static let blunder = Color(red: 0.980, green: 0.255, blue: 0.176)

    static func color(for outcome: GameOutcome) -> Color {
        switch outcome {
        case .win: return win
        case .loss: return loss
        case .draw: return textSecondary
        }
    }

    static let cardShape = RoundedRectangle(cornerRadius: 20, style: .continuous)
}
