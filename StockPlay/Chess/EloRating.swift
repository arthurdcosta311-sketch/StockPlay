//
//  EloRating.swift
//  StockPlay
//
//  A chess.com-style Elo system: expected score, K-factor and rating changes.
//

import Foundation

enum EloRating {
    /// A new account starts here.
    static let startingRating = 500
    /// Ratings never fall below this.
    static let ratingFloor = 100
    /// Games played before a rating stops being provisional.
    static let provisionalGameCount = 8

    /// The grandmaster is shown as 99999, but no one can be rated against a literal 99999:
    /// the expected score would be zero and every loss would be free. Rating is calculated
    /// as if the engine sat 300 points above the player, so a loss costs about 6 points and
    /// a win pays about 34 while the rating is provisional.
    static let ratingGap = 300

    /// The opponent rating used for the maths behind a displayed rating.
    static func calculationRating(playerRating: Int, opponentRating: Int) -> Int {
        return min(opponentRating, playerRating + ratingGap)
    }

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

    /// Whole-point change for one game: a loss takes points away, a win pays, a draw is neutral.
    static func ratingChange(rating: Int, opponentRating: Int, score: Double, gamesPlayed: Int) -> Int {
        if score == 0.5 { return 0 }

        let opponent = calculationRating(playerRating: rating, opponentRating: opponentRating)
        let expected = expectedScore(rating: rating, opponentRating: opponent)
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
        return max(ratingFloor, rating + change)
    }
}
