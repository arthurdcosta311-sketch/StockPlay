//
//  PlayerStore.swift
//  Grandmaster
//
//  The player's rating, record and game history, kept on the device.
//

import Foundation
import Observation

struct RatingChange: Equatable, Sendable {
    let before: Int
    let after: Int

    var delta: Int { return after - before }

    var deltaText: String {
        if delta > 0 { return "+\(delta)" }
        return "\(delta)"
    }
}

struct GameRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let outcome: GameOutcome
    let reason: String
    let playerColor: ChessColor
    let ratingBefore: Int
    let ratingAfter: Int
    let moveCount: Int
    let pgn: String

    var delta: Int { return ratingAfter - ratingBefore }

    var deltaText: String {
        if delta > 0 { return "+\(delta)" }
        return "\(delta)"
    }
}

struct PlayerProfile: Codable, Sendable {
    var rating: Int = 1200
    var peakRating: Int = 1200
    var games: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var draws: Int = 0
    var history: [GameRecord] = []

    var isProvisional: Bool {
        return games < EloRating.provisionalGameCount
    }

    /// Chess.com shows a provisional rating with a question mark.
    var ratingText: String {
        return isProvisional ? "\(rating)?" : "\(rating)"
    }
}

@Observable
final class PlayerStore {
    static let shared = PlayerStore()

    private(set) var profile: PlayerProfile

    private let defaults: UserDefaults
    private let storageKey = "grandmaster.player.profile.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            profile = decoded
        } else {
            profile = PlayerProfile()
        }
    }

    @discardableResult
    func record(
        outcome: GameOutcome,
        reason: String,
        playerColor: ChessColor,
        moveCount: Int,
        pgn: String,
        opponentRating: Int
    ) -> RatingChange {
        let before = profile.rating
        let after = EloRating.newRating(
            rating: before,
            opponentRating: opponentRating,
            score: outcome.score,
            gamesPlayed: profile.games
        )

        profile.rating = after
        profile.peakRating = max(profile.peakRating, after)
        profile.games += 1
        switch outcome {
        case .win: profile.wins += 1
        case .loss: profile.losses += 1
        case .draw: profile.draws += 1
        }

        let record = GameRecord(
            id: UUID(),
            date: Date(),
            outcome: outcome,
            reason: reason,
            playerColor: playerColor,
            ratingBefore: before,
            ratingAfter: after,
            moveCount: moveCount,
            pgn: pgn
        )
        profile.history.insert(record, at: 0)
        if profile.history.count > 40 {
            profile.history = Array(profile.history.prefix(40))
        }

        persist()
        return RatingChange(before: before, after: after)
    }

    func resetRating() {
        profile = PlayerProfile()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
