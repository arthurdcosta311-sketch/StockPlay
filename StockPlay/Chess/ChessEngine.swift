//
//  ChessEngine.swift
//  StockPlay
//
//  The grandmaster opponent: a small opening book on top of an
//  alpha-beta search with quiescence. Every search carries its own state.
//

import Foundation

struct EngineLimits: Sendable {
    var maxDepth: Int
    var timeLimit: TimeInterval

    init(maxDepth: Int = 6, timeLimit: TimeInterval = 1.4) {
        self.maxDepth = maxDepth
        self.timeLimit = timeLimit
    }
}

/// A handful of real openings, so the grandmaster starts like one.
enum OpeningBook {
    private static let sequences: [[String]] = [
        // 1.e4 e5 — the open game
        ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6"],
        ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "c2c3", "g8f6"],
        ["e2e4", "e7e5", "g1f3", "g8f6", "f3e5", "d7d6", "e5f3", "f6e4"],
        ["e2e4", "e7e5", "b1c3", "g8f6", "f1c4", "f8b4"],
        // 1.e4 — Sicilian, French, Caro-Kann, Scandinavian
        ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4", "f3d4", "g8f6"],
        ["e2e4", "c7c5", "g1f3", "b8c6", "d2d4", "c5d4", "f3d4", "g8f6"],
        ["e2e4", "e7e6", "d2d4", "d7d5", "b1c3", "g8f6"],
        ["e2e4", "c7c6", "d2d4", "d7d5", "b1c3", "d5e4"],
        ["e2e4", "d7d5", "e4d5", "d8d5", "b1c3", "d5a5"],
        // 1.d4 — closed games
        ["d2d4", "d7d5", "c2c4", "e7e6", "b1c3", "g8f6"],
        ["d2d4", "d7d5", "c2c4", "c7c6", "g1f3", "g8f6"],
        ["d2d4", "g8f6", "c2c4", "e7e6", "b1c3", "f8b4"],
        ["d2d4", "g8f6", "g1f3", "e7e6", "c2c4", "d7d5"],
        ["d2d4", "d7d5", "g1f3", "g8f6", "c2c4", "e7e6"],
        // 1.c4 and 1.Nf3
        ["c2c4", "e7e5", "b1c3", "g8f6", "g2g3", "d7d5"],
        ["c2c4", "g8f6", "d2d4", "e7e6", "b1c3", "f8b4"],
        ["g1f3", "d7d5", "d2d4", "g8f6", "c2c4", "e7e6"],
        ["g1f3", "g8f6", "d2d4", "e7e6", "c2c4", "d7d5"],
    ]

    private static let candidates: [String: [String]] = build()

    static func move(in board: ChessBoard) -> Move? {
        guard let uci = candidates[board.positionKey]?.randomElement() else { return nil }
        let matches = board.legalMoves.filter { $0.uci == uci }
        return matches.first(where: { $0.promotion == nil }) ?? matches.first
    }

    private static func build() -> [String: [String]] {
        var map: [String: [String]] = [:]
        for sequence in sequences {
            var board = ChessBoard.initial
            for uci in sequence {
                guard let move = board.legalMoves.first(where: { $0.uci == uci }) else { break }
                var list = map[board.positionKey] ?? []
                if !list.contains(uci) {
                    list.append(uci)
                }
                map[board.positionKey] = list
                board = board.applying(move)
            }
        }
        return map
    }
}

final class ChessEngine {
    /// Best move for the side to move, or nil when the position is already over.
    func searchBestMove(in board: ChessBoard, limits: EngineLimits = EngineLimits()) -> Move? {
        if let bookMove = OpeningBook.move(in: board) {
            return bookMove
        }

        let rootMoves = board.legalMoves
        guard let first = rootMoves.first else { return nil }
        guard rootMoves.count > 1 else { return first }

        let search = Search(deadline: Date().addingTimeInterval(limits.timeLimit))
        var bestMove = first
        var bestScore = -Search.mateScore

        for depth in 1...max(1, limits.maxDepth) {
            var alpha = -Search.mateScore
            let beta = Search.mateScore
            var iterationMove = bestMove
            var iterationScore = -Search.mateScore
            var completed = true

            for move in search.ordered(rootMoves, board: board) {
                let score = -search.negamax(
                    board.applying(move),
                    depth: depth - 1,
                    alpha: -beta,
                    beta: -alpha,
                    ply: 1
                )
                if search.cancelled {
                    completed = false
                    break
                }
                // A hair of randomness keeps repeat games from being identical.
                let jittered = score + Int.random(in: 0...2)
                if jittered > iterationScore {
                    iterationScore = jittered
                    iterationMove = move
                }
                if score > alpha {
                    alpha = score
                }
            }

            if completed && iterationScore > bestScore {
                bestScore = iterationScore
                bestMove = iterationMove
            }

            if search.cancelled || Date() >= search.deadline {
                break
            }
        }

        return bestMove
    }
}

/// One search: its own node count, deadline and cancellation flag.
private final class Search {
    static let mateScore = 100_000

    let deadline: Date
    private(set) var cancelled = false
    private var nodes = 0

    init(deadline: Date) {
        self.deadline = deadline
    }

    func negamax(_ board: ChessBoard, depth: Int, alpha: Int, beta: Int, ply: Int) -> Int {
        nodes += 1
        if nodes % 1024 == 0, Date() >= deadline {
            cancelled = true
        }
        if cancelled {
            return evaluate(board)
        }
        if board.halfmoveClock >= 100 {
            return 0
        }

        let moves = board.legalMoves
        if moves.isEmpty {
            return board.isInCheck(board.sideToMove) ? -Search.mateScore + ply : 0
        }
        if depth <= 0 {
            return quiescence(board, alpha: alpha, beta: beta, depth: 0)
        }

        var alpha = alpha
        var best = -Search.mateScore

        for move in ordered(moves, board: board) {
            let score = -negamax(board.applying(move), depth: depth - 1, alpha: -beta, beta: -alpha, ply: ply + 1)
            if cancelled { break }
            if score > best { best = score }
            if score > alpha { alpha = score }
            if alpha >= beta { break }
        }

        return best
    }

    private func quiescence(_ board: ChessBoard, alpha: Int, beta: Int, depth: Int) -> Int {
        nodes += 1
        if nodes % 1024 == 0, Date() >= deadline {
            cancelled = true
        }

        var alpha = alpha
        let standPat = evaluate(board)
        if depth >= 4 || standPat >= beta {
            return standPat
        }
        if standPat > alpha { alpha = standPat }

        let captures = board.legalMoves.filter { move in
            return move.promotion != nil || move.isEnPassant || board.piece(at: move.to) != nil
        }

        for move in ordered(captures, board: board) {
            let score = -quiescence(board.applying(move), alpha: -beta, beta: -alpha, depth: depth + 1)
            if cancelled { return alpha }
            if score >= beta { return score }
            if score > alpha { alpha = score }
        }

        return alpha
    }

    func ordered(_ moves: [Move], board: ChessBoard) -> [Move] {
        func orderScore(_ move: Move) -> Int {
            var value = 0
            if let victim = board.piece(at: move.to) {
                value += 10 * victim.kind.value
            }
            if move.isEnPassant {
                value += 10 * PieceKind.pawn.value
            }
            if let promotion = move.promotion {
                value += promotion.value
            }
            if move.isCastling {
                value += 40
            }
            return value
        }
        return moves.sorted { orderScore($0) > orderScore($1) }
    }

    // MARK: - Evaluation

    /// Score in centipawns from the point of view of the side to move.
    private func evaluate(_ board: ChessBoard) -> Int {
        var score = 0
        var whiteBishops = 0
        var blackBishops = 0
        var whitePawnFiles = [Int](repeating: 0, count: 8)
        var blackPawnFiles = [Int](repeating: 0, count: 8)
        var material = 0

        for index in 0..<64 {
            guard let piece = board.squares[index], let square = Square(index: index) else { continue }
            let base = piece.kind.value
            var bonus = 0

            switch piece.kind {
            case .pawn:
                let advance = piece.color == .white ? square.rank : 7 - square.rank
                bonus = advance * 9
                if piece.color == .white {
                    whitePawnFiles[square.file] += 1
                } else {
                    blackPawnFiles[square.file] += 1
                }
            case .knight:
                bonus = centrality(square) * 6
            case .bishop:
                bonus = centrality(square) * 4
                if piece.color == .white {
                    whiteBishops += 1
                } else {
                    blackBishops += 1
                }
            case .rook:
                bonus = square.rank == (piece.color == .white ? 6 : 1) ? 12 : 0
            case .queen:
                bonus = centrality(square) * 2
            case .king:
                bonus = 0
            }

            material += base
            let value = base + bonus
            score += piece.color == .white ? value : -value
        }

        let inEndgame = material < 2600

        if let whiteKing = board.kingSquare(for: .white) {
            score += kingBonus(whiteKing, inEndgame: inEndgame)
        }
        if let blackKing = board.kingSquare(for: .black) {
            score -= kingBonus(blackKing, inEndgame: inEndgame)
        }

        if whiteBishops >= 2 { score += 28 }
        if blackBishops >= 2 { score -= 28 }

        for file in 0..<8 {
            if whitePawnFiles[file] > 1 {
                score -= 14 * (whitePawnFiles[file] - 1)
            }
            if blackPawnFiles[file] > 1 {
                score += 14 * (blackPawnFiles[file] - 1)
            }
        }

        return board.sideToMove == .white ? score : -score
    }

    private func kingBonus(_ square: Square, inEndgame: Bool) -> Int {
        let central = centrality(square)
        if inEndgame {
            return central * 4
        }
        // Tucked away behind the pawns is safest in the middlegame.
        return (6 - central) * 3
    }

    /// 0 on the edge of the board, 6 on the four central squares.
    private func centrality(_ square: Square) -> Int {
        return fileCentrality(square.file) + rankCentrality(square.rank)
    }

    private func fileCentrality(_ file: Int) -> Int {
        return 3 - abs(file * 2 - 7) / 2
    }

    private func rankCentrality(_ rank: Int) -> Int {
        return 3 - abs(rank * 2 - 7) / 2
    }
}
