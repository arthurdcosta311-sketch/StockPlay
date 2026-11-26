//
//  EloRating.swift
//  Grandmaster
//
//  A chess.com-style Elo system: expected score, K-factor and rating changes.
//

import Foundation

enum EloRating {
    /// Games played before a rating stops being provisional.
    static let provisionalGameCount = 8

    /// Probability that `rating` scores against `opponentRating`, between 0 and 1.
    static func expectedScore(rating: Int, opponentRating: Int) -> Double {
        let difference = Double(opponentRating - rating)
        return 1.0 / (1.0 + pow(10.0, difference / 400.0))
    }

    /// Larger K while provisional (ratings settle fast), then smaller as the rating stabilises.
    static func kFactor(rating: Int, gamesPlayed: Int) -> Double {
        if gamesPlayed < provisionalGameCount { return 40 }
        if rating < 2100 { return 24 }
        if rating < 2400 { return 16 }
        return 12
    }

    /// Whole-point change for one game. Beating a far stronger opponent pays; losing costs almost nothing.
    static func ratingChange(rating: Int, opponentRating: Int, score: Double, gamesPlayed: Int) -> Int {
        let expected = expectedScore(rating: rating, opponentRating: opponentRating)
        let delta = kFactor(rating: rating, gamesPlayed: gamesPlayed) * (score - expected)
        if abs(delta) < 1 {
            if delta > 0 { return 1 }
            if delta < 0 { return -1 }
            return 0
        }
        return Int(delta.rounded())
    }

    static func newRating(rating: Int, opponentRating: Int, score: Double, gamesPlayed: Int) -> Int {
        let change = ratingChange(rating: rating, opponentRating: opponentRating, score: score, gamesPlayed: gamesPlayed)
        return max(100, rating + change)
    }
}
