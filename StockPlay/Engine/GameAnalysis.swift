//
//  GameAnalysis.swift
//  StockPlay
//
//  One question asked of the engine: how good is this position, and what is the best move?
//

import Foundation

struct EngineAssessment: Sendable {
    /// The engine's move in long algebraic notation.
    var bestMove: String?
    /// Centipawns from the side to move, with a mate folded in as a large score.
    var score: Int
    /// Mate in this many moves, positive when the side to move mates.
    var mate: Int?
    var fromStockfish: Bool

    static let empty = EngineAssessment(bestMove: nil, score: 0, mate: nil, fromStockfish: false)
}

enum GameAnalysis {
    /// Short looks used while a game is being played.
    static let liveMilliseconds = 200
    /// A little longer for the review after the game.
    static let reviewMilliseconds = 220

    /// Stockfish when its network is ready, otherwise the built-in engine.
    static func assess(_ board: ChessBoard, milliseconds: Int = reviewMilliseconds) async -> EngineAssessment {
        // A finished position has no move to suggest: a mate against the side to move, or a draw.
        if board.legalMoves.isEmpty {
            let score = board.isInCheck(board.sideToMove) ? -ReviewMath.mateCentipawns : 0
            return EngineAssessment(bestMove: nil, score: score, mate: nil, fromStockfish: false)
        }

        if let assessment = await StockfishService.shared.assess(fen: board.fen, milliseconds: milliseconds) {
            return assessment
        }

        let fallback = await Task.detached(priority: .userInitiated) { () -> EngineAssessment in
            let engine = ChessEngine()
            guard let result = engine.search(in: board, limits: EngineLimits(maxDepth: 4, timeLimit: 0.3)) else {
                return .empty
            }
            return EngineAssessment(bestMove: result.move.uci, score: result.score, mate: nil, fromStockfish: false)
        }.value

        return fallback
    }
}
