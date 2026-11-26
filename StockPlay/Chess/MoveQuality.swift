//
//  MoveQuality.swift
//  StockPlay
//
//  How good a move was, the way chess.com labels them, and the maths behind it.
//

import SwiftUI

enum MoveQuality: String, Sendable, CaseIterable, Identifiable {
    case brilliant
    case best
    case excellent
    case good
    case book
    case inaccuracy
    case mistake
    case blunder

    var id: String { return rawValue }

    var title: String {
        switch self {
        case .brilliant: return "Brilliant"
        case .best: return "Best"
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .book: return "Book"
        case .inaccuracy: return "Inaccuracy"
        case .mistake: return "Mistake"
        case .blunder: return "Blunder"
        }
    }

    var symbol: String {
        switch self {
        case .brilliant: return "sparkles"
        case .best: return "checkmark.seal.fill"
        case .excellent: return "checkmark"
        case .good: return "checkmark.circle"
        case .book: return "book.fill"
        case .inaccuracy: return "exclamationmark.triangle.fill"
        case .mistake: return "questionmark.circle.fill"
        case .blunder: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .brilliant: return Theme.brilliant
        case .best, .excellent: return Theme.best
        case .good: return Theme.good
        case .book: return Theme.book
        case .inaccuracy: return Theme.inaccuracy
        case .mistake: return Theme.mistake
        case .blunder: return Theme.blunder
        }
    }

    /// Whether the move deserves praise rather than a warning.
    var isPraise: Bool {
        switch self {
        case .brilliant, .best, .excellent, .good, .book: return true
        case .inaccuracy, .mistake, .blunder: return false
        }
    }

    /// Shown in the review legend.
    var explanation: String {
        switch self {
        case .brilliant: return "The engine's choice, and a sacrifice"
        case .best: return "The engine's choice"
        case .excellent: return "Almost as good as the best"
        case .good: return "A sound move"
        case .book: return "Theory from the opening book"
        case .inaccuracy: return "Lets the position slip"
        case .mistake: return "Gives away a real advantage"
        case .blunder: return "Throws the game away"
        }
    }
}

struct ReviewItem: Identifiable, Sendable {
    let id: Int
    let moveNumber: Int
    let color: ChessColor
    let san: String
    let quality: MoveQuality
    let bestSAN: String?
    let winDrop: Double
}

struct GameReview: Sendable {
    var items: [ReviewItem]
    var playerAccuracy: Int
    var engineAccuracy: Int
    var playerCounts: [MoveQuality: Int]
    var engineCounts: [MoveQuality: Int]
    var playerColor: ChessColor

    func count(_ quality: MoveQuality, for color: ChessColor) -> Int {
        return (color == playerColor ? playerCounts : engineCounts)[quality] ?? 0
    }
}

enum ReviewMath {
    /// A mate is folded into a large centipawn score so positions can be compared.
    static let mateCentipawns = 9_000

    static func clamped(_ centipawns: Int) -> Int {
        return min(mateCentipawns, max(-mateCentipawns, centipawns))
    }

    /// Winning chances in percent, the curve chess.com and Lichess both use.
    static func winPercent(centipawns: Int) -> Double {
        let value = Double(clamped(centipawns))
        return 50 + 50 * (2 / (1 + exp(-0.00368208 * value)) - 1)
    }

    /// Accuracy between 0 and 100 for one move, from how much winning chances it lost.
    static func accuracy(winDrop: Double) -> Double {
        let raw = 103.1668 * exp(-0.04354 * abs(winDrop)) - 3.1669
        return min(100, max(0, raw))
    }

    static func classify(winDrop: Double, isBestMove: Bool, isBook: Bool, isBrilliant: Bool) -> MoveQuality {
        if isBook { return .book }
        if isBestMove { return isBrilliant ? .brilliant : .best }
        if winDrop <= 2 { return .excellent }
        if winDrop <= 5 { return .good }
        if winDrop <= 10 { return .inaccuracy }
        if winDrop <= 20 { return .mistake }
        return .blunder
    }
}
