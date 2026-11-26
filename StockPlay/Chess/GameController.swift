//
//  GameController.swift
//  StockPlay
//
//  One rated game against the grandmaster: board, clock, engine turns and the rating update.
//

import Foundation
import Observation

struct TimeControl: Identifiable, Hashable, Sendable {
    let id: String
    let baseSeconds: Int
    let incrementSeconds: Int

    var isUnlimited: Bool { return baseSeconds == 0 }

    var label: String {
        if isUnlimited { return "Unlimited" }
        let minutes = baseSeconds / 60
        if incrementSeconds > 0 {
            return "\(minutes) min + \(incrementSeconds)s"
        }
        return "\(minutes) min"
    }

    var shortLabel: String {
        if isUnlimited { return "Unlimited" }
        if incrementSeconds > 0 { return "\(baseSeconds / 60)+\(incrementSeconds)" }
        return "\(baseSeconds / 60) min"
    }

    static let all: [TimeControl] = [
        TimeControl(id: "unlimited", baseSeconds: 0, incrementSeconds: 0),
        TimeControl(id: "3+2", baseSeconds: 180, incrementSeconds: 2),
        TimeControl(id: "5+0", baseSeconds: 300, incrementSeconds: 0),
        TimeControl(id: "10+0", baseSeconds: 600, incrementSeconds: 0),
    ]
}

struct MoveEntry: Identifiable, Sendable {
    let id: Int
    let san: String
    let color: ChessColor
    let moveNumber: Int
    var quality: MoveQuality?
    var bestSAN: String?
}

/// A piece on the board with an identity that survives moves, so it can slide between squares.
struct BoardPiece: Identifiable, Sendable, Equatable {
    let id: Int
    let piece: Piece
    let square: Square
}

@MainActor
@Observable
final class GameController: Identifiable {
    static let opponentName = "Stockfish 19"
    static let opponentTitle = "GM"
    static let opponentRating = 99999

    enum Phase: Equatable, Sendable {
        case playing
        case finished
    }

    let id = UUID()
    let playerColor: ChessColor
    let timeControl: TimeControl

    private(set) var board: ChessBoard
    private(set) var entries: [MoveEntry] = []
    private(set) var lastMove: Move?
    private(set) var phase: Phase = .playing
    private(set) var end: GameEnd?
    private(set) var ratingChange: RatingChange?
    private(set) var isEngineThinking = false
    private(set) var clocks: [ChessColor: TimeInterval] = [:]

    var selectedSquare: Square?
    var legalTargets: [Square] = []
    var isBoardFlipped: Bool

    /// Bumped on every board change so the view can animate moves.
    private(set) var animationToken = 0

    private var identities: [Int?]
    private var identityHistory: [[Int?]] = []
    private var nextIdentity: Int
    private var boardHistory: [ChessBoard] = []
    private var moveHistory: [Move] = []

    private(set) var review: GameReview?
    private(set) var reviewProgress: Double = 0
    private(set) var isReviewing = false

    private var classificationTask: Task<Void, Never>?
    private var reviewTask: Task<Void, Never>?
    private var repetitions: [String: Int] = [:]
    private var engineTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var hasStarted = false
    private var startDate = Date()

    init(playerColor: ChessColor, timeControl: TimeControl) {
        self.playerColor = playerColor
        self.timeControl = timeControl
        self.board = .initial
        self.isBoardFlipped = playerColor == .black
        self.clocks = [
            .white: TimeInterval(timeControl.baseSeconds),
            .black: TimeInterval(timeControl.baseSeconds),
        ]
        self.repetitions = [ChessBoard.initial.positionKey: 1]

        var startIdentities = [Int?](repeating: nil, count: 64)
        var identity = 0
        for index in 0..<64 where ChessBoard.initial.squares[index] != nil {
            startIdentities[index] = identity
            identity += 1
        }
        self.identities = startIdentities
        self.nextIdentity = identity
    }

    // MARK: - Presentation helpers

    var statusText: String {
        if phase == .finished, let end = end {
            return end.reason
        }
        if board.isInCheck(board.sideToMove) {
            return board.sideToMove == playerColor ? "Check — defend your king" : "Check"
        }
        if isEngineThinking {
            return "\(Self.opponentName) is thinking"
        }
        if board.sideToMove == playerColor {
            return "Your move"
        }
        return "Waiting for the engine"
    }

    var isPlayersTurn: Bool {
        return phase == .playing && board.sideToMove == playerColor && !isEngineThinking
    }

    func clockText(for color: ChessColor) -> String? {
        guard !timeControl.isUnlimited else { return nil }
        let remaining = max(0, clocks[color] ?? 0)
        if remaining < 20 {
            return String(format: "%.1f", remaining)
        }
        let total = Int(remaining)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Lifecycle

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        startDate = Date()
        startClock()
        if board.sideToMove != playerColor {
            triggerEngineMove()
        }
    }

    func toggleFlip() {
        isBoardFlipped.toggle()
    }

    func clearSelection() {
        selectedSquare = nil
        legalTargets = []
    }

    /// The pieces to draw, each carrying its identity so it slides rather than jumps.
    var boardPieces: [BoardPiece] {
        var result: [BoardPiece] = []
        result.reserveCapacity(32)
        for index in 0..<64 {
            guard let piece = board.squares[index], let square = Square(index: index) else { continue }
            // A stable fallback keeps a piece on screen even if an identity ever goes missing.
            let identity = identities[index] ?? (10_000 + index)
            result.append(BoardPiece(id: identity, piece: piece, square: square))
        }
        return result
    }

    // MARK: - Player input

    func handleTap(_ square: Square) {
        guard isPlayersTurn else { return }

        if let selected = selectedSquare, legalTargets.contains(square) {
            let candidates = board.legalMoves.filter { $0.from == selected && $0.to == square }
            guard let move = candidates.first(where: { $0.promotion == .queen }) ?? candidates.first else {
                clearSelection()
                return
            }
            clearSelection()
            perform(move)
            return
        }

        if let piece = board.piece(at: square), piece.color == playerColor {
            selectedSquare = square
            legalTargets = board.legalMoves.filter { $0.from == square }.map { $0.to }
        } else {
            clearSelection()
        }
    }

    func resign() {
        guard phase == .playing else { return }
        engineTask?.cancel()
        isEngineThinking = false
        finish(.resignation(winner: playerColor.opposite))
    }

    func takeback() {
        guard phase == .playing else { return }
        engineTask?.cancel()
        classificationTask?.cancel()
        isEngineThinking = false

        var undone = 0
        while !boardHistory.isEmpty {
            let key = board.positionKey
            repetitions[key] = max(0, (repetitions[key] ?? 1) - 1)
            board = boardHistory.removeLast()
            if !identityHistory.isEmpty {
                identities = identityHistory.removeLast()
            }
            if !entries.isEmpty {
                entries.removeLast()
            }
            if !moveHistory.isEmpty {
                moveHistory.removeLast()
            }
            undone += 1
            if board.sideToMove == playerColor { break }
        }

        guard undone > 0 else { return }
        animationToken += 1
        lastMove = nil
        clearSelection()
        if board.sideToMove != playerColor {
            triggerEngineMove()
        }
    }

    // MARK: - Play

    private func perform(_ move: Move) {
        guard phase == .playing else { return }
        let san = board.san(for: move)
        let mover = board.sideToMove
        let moveNumber = board.fullmoveNumber

        let previousPosition = board
        boardHistory.append(board)
        identityHistory.append(identities)
        let entryIndex = entries.count
        entries.append(MoveEntry(id: entryIndex, san: san, color: mover, moveNumber: moveNumber))
        moveHistory.append(move)

        board = board.applying(move)
        updateIdentities(for: move)
        animationToken += 1
        lastMove = move
        repetitions[board.positionKey, default: 0] += 1

        if mover == playerColor {
            classifyLive(move: move, before: previousPosition, entryIndex: entryIndex)
        }

        if !timeControl.isUnlimited, let remaining = clocks[mover] {
            clocks[mover] = remaining + TimeInterval(timeControl.incrementSeconds)
        }

        if let finished = detectEnd() {
            finish(finished)
            return
        }
        if board.sideToMove != playerColor {
            triggerEngineMove()
        }
    }

    /// Carries each piece's identity from its old square to its new one.
    private func updateIdentities(for move: Move) {
        let capturedSquare = move.isEnPassant ? Square(file: move.to.file, rank: move.from.rank) : move.to
        identities[capturedSquare.index] = nil
        identities[move.to.index] = nil

        if move.isCastling {
            let rank = move.from.rank
            let kingside = move.to.file == 6
            let rookFrom = Square(file: kingside ? 7 : 0, rank: rank)
            let rookTo = Square(file: kingside ? 5 : 3, rank: rank)
            identities[rookTo.index] = identities[rookFrom.index]
            identities[rookFrom.index] = nil
        }

        if move.promotion != nil {
            identities[move.to.index] = nextIdentity
            nextIdentity += 1
        } else {
            identities[move.to.index] = identities[move.from.index]
        }

        identities[move.from.index] = nil
    }

    private func detectEnd() -> GameEnd? {
        return board.gameEnd(repetitions: repetitions[board.positionKey] ?? 1)
    }

    private func triggerEngineMove() {
        guard phase == .playing else { return }
        engineTask?.cancel()
        isEngineThinking = true

        let position = board
        let limits = EngineLimits(maxDepth: 6, timeLimit: 1.5)

        engineTask = Task { [weak self] in
            guard let self = self else { return }
            let startedAt = Date()

            var chosen: Move? = nil

            // Stockfish when its network is ready…
            if let uci = await StockfishService.shared.uciMove(fen: position.fen, milliseconds: 900) {
                chosen = position.legalMoves.first(where: { $0.uci == uci })
            }

            // …the built-in engine otherwise.
            if chosen == nil {
                chosen = await Task.detached(priority: .userInitiated) { () -> Move? in
                    return ChessEngine().searchBestMove(in: position, limits: limits)
                }.value
            }

            guard !Task.isCancelled else { return }

            // A short beat so the grandmaster feels like it is considering.
            let elapsed = Date().timeIntervalSince(startedAt)
            if elapsed < 0.4 {
                try? await Task.sleep(for: .milliseconds(Int((0.4 - elapsed) * 1000)))
            }
            guard !Task.isCancelled else { return }
            guard self.phase == .playing else { return }

            self.isEngineThinking = false

            guard let move = chosen else {
                if let finished = self.detectEnd() {
                    self.finish(finished)
                }
                return
            }

            if let legal = self.board.legalMoves.first(where: { $0.uci == move.uci }) {
                self.perform(legal)
            } else if let fallback = self.board.legalMoves.first {
                self.perform(fallback)
            }
        }
    }

    private func finish(_ finished: GameEnd) {
        guard phase == .playing else { return }
        phase = .finished
        end = finished
        engineTask?.cancel()
        clockTask?.cancel()
        isEngineThinking = false
        clearSelection()

        ratingChange = PlayerStore.shared.record(
            outcome: finished.outcome(for: playerColor),
            reason: finished.playerReason(for: playerColor),
            playerColor: playerColor,
            moveCount: entries.count,
            pgn: pgn(),
            opponentRating: Self.opponentRating
        )
    }

    // MARK: - Clock

    private func startClock() {
        guard !timeControl.isUnlimited else { return }
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self = self else { return }
                guard self.phase == .playing else { return }

                let side = self.board.sideToMove
                let remaining = (self.clocks[side] ?? 0) - 0.1
                if remaining <= 0 {
                    self.clocks[side] = 0
                    self.finish(.timeout(winner: side.opposite))
                    return
                }
                self.clocks[side] = remaining
            }
        }
    }

    // MARK: - Move quality

    /// Asks the engine what the best move was, and what the move you played cost.
    private func classifyLive(move: Move, before: ChessBoard, entryIndex: Int) {
        classificationTask?.cancel()
        let isBook = OpeningBook.isBookMove(move, in: before)

        classificationTask = Task { [weak self] in
            guard let self = self else { return }

            var quality: MoveQuality = .book
            var bestSAN: String? = nil

            if !isBook {
                let beforeAssessment = await GameAnalysis.assess(before, milliseconds: GameAnalysis.liveMilliseconds)
                if Task.isCancelled { return }
                let afterPosition = before.applying(move)
                let afterAssessment = await GameAnalysis.assess(afterPosition, milliseconds: GameAnalysis.liveMilliseconds)
                if Task.isCancelled { return }

                let scoreBefore = beforeAssessment.score
                let scoreAfter = -afterAssessment.score
                let winDrop = ReviewMath.winPercent(centipawns: scoreBefore) - ReviewMath.winPercent(centipawns: scoreAfter)

                let isMate = afterPosition.legalMoves.isEmpty && afterPosition.isInCheck(afterPosition.sideToMove)
                let isBest = isMate || beforeAssessment.bestMove == move.uci
                let brilliant = isBest && self.isSacrifice(move, before: before, after: afterPosition, scoreBefore: scoreBefore)
                quality = ReviewMath.classify(winDrop: winDrop, isBestMove: isBest, isBook: false, isBrilliant: brilliant)

                if !isBest, let bestUCI = beforeAssessment.bestMove,
                   let best = before.legalMoves.first(where: { $0.uci == bestUCI }) {
                    bestSAN = before.san(for: best)
                }
            }

            guard !Task.isCancelled else { return }
            self.applyQuality(quality, bestSAN: bestSAN, at: entryIndex)
        }
    }

    /// The verdict badge for the board: on the square your latest annotated move went to.
    var lastMoveBadge: MoveBadge? {
        guard let index = entries.lastIndex(where: { $0.color == playerColor && $0.quality != nil }),
              entries.indices.contains(index),
              moveHistory.indices.contains(index),
              let quality = entries[index].quality else {
            return nil
        }
        return MoveBadge(square: moveHistory[index].to, quality: quality)
    }

    private func applyQuality(_ quality: MoveQuality, bestSAN: String?, at index: Int) {
        guard entries.indices.contains(index), entries[index].id == index else { return }
        entries[index].quality = quality
        entries[index].bestSAN = bestSAN
    }

    /// A sacrifice: the engine's own move, giving away a piece worth more than its attacker.
    private func isSacrifice(_ move: Move, before: ChessBoard, after: ChessBoard, scoreBefore: Int) -> Bool {
        guard scoreBefore > 50 else { return false }
        guard let piece = before.piece(at: move.from), piece.kind != .pawn, piece.kind != .king else {
            return false
        }
        return after.isAttackedByCheaperPiece(move.to, by: piece.color.opposite, than: piece.kind.value)
    }

    // MARK: - Game review

    func startReview() {
        guard review == nil, !isReviewing else { return }
        guard !moveHistory.isEmpty else { return }

        let positions = boardHistory + [board]
        guard positions.count == moveHistory.count + 1 else { return }

        let moves = moveHistory
        isReviewing = true
        reviewProgress = 0

        reviewTask = Task { [weak self] in
            guard let self = self else { return }

            var assessments: [EngineAssessment] = []
            assessments.reserveCapacity(positions.count)

            for (index, position) in positions.enumerated() {
                if Task.isCancelled { return }
                let assessment = await GameAnalysis.assess(position, milliseconds: GameAnalysis.reviewMilliseconds)
                assessments.append(assessment)
                self.reviewProgress = Double(index + 1) / Double(positions.count)
            }

            guard !Task.isCancelled, assessments.count == positions.count else {
                self.isReviewing = false
                return
            }

            self.review = self.buildReview(positions: positions, moves: moves, assessments: assessments)
            self.isReviewing = false
        }
    }

    private func buildReview(positions: [ChessBoard], moves: [Move], assessments: [EngineAssessment]) -> GameReview {
        var items: [ReviewItem] = []
        var playerAccuracies: [Double] = []
        var engineAccuracies: [Double] = []
        var playerCounts: [MoveQuality: Int] = [:]
        var engineCounts: [MoveQuality: Int] = [:]

        for (index, move) in moves.enumerated() {
            guard index + 1 < assessments.count, index < positions.count else { break }
            let before = positions[index]
            let after = before.applying(move)
            let mover = before.sideToMove

            let scoreBefore = assessments[index].score
            let scoreAfter = -assessments[index + 1].score
            let winDrop = ReviewMath.winPercent(centipawns: scoreBefore) - ReviewMath.winPercent(centipawns: scoreAfter)

            let isBook = OpeningBook.isBookMove(move, in: before)
            let bestUCI = assessments[index].bestMove
            let isMate = after.legalMoves.isEmpty && after.isInCheck(after.sideToMove)
            let isBest = isMate || bestUCI == move.uci
            let brilliant = isBest && isSacrifice(move, before: before, after: after, scoreBefore: scoreBefore)
            let quality = ReviewMath.classify(winDrop: winDrop, isBestMove: isBest, isBook: isBook, isBrilliant: brilliant)

            var bestSAN: String? = nil
            if !isBest, let bestUCI = bestUCI, let best = before.legalMoves.first(where: { $0.uci == bestUCI }) {
                bestSAN = before.san(for: best)
            }

            let accuracy = ReviewMath.accuracy(winDrop: winDrop)
            if mover == playerColor {
                playerAccuracies.append(accuracy)
                playerCounts[quality, default: 0] += 1
            } else {
                engineAccuracies.append(accuracy)
                engineCounts[quality, default: 0] += 1
            }

            let san = entries.indices.contains(index) ? entries[index].san : move.uci
            items.append(
                ReviewItem(
                    id: index,
                    moveNumber: before.fullmoveNumber,
                    color: mover,
                    san: san,
                    quality: quality,
                    bestSAN: bestSAN,
                    winDrop: winDrop
                )
            )
        }

        return GameReview(
            items: items,
            playerAccuracy: Int(average(playerAccuracies).rounded()),
            engineAccuracy: Int(average(engineAccuracies).rounded()),
            playerCounts: playerCounts,
            engineCounts: engineCounts,
            playerColor: playerColor
        )
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Score sheet

    var moveText: String {
        var parts: [String] = []
        var index = 0
        while index < entries.count {
            let entry = entries[index]
            if entry.color == .white {
                var text = "\(entry.moveNumber). \(entry.san)"
                index += 1
                if index < entries.count, entries[index].color == .black {
                    text += " " + entries[index].san
                    index += 1
                }
                parts.append(text)
            } else {
                parts.append("\(entry.moveNumber)... \(entry.san)")
                index += 1
            }
        }
        return parts.joined(separator: " ")
    }

    private func resultString() -> String {
        guard let end = end else { return "*" }
        guard let winner = end.winner else { return "1/2-1/2" }
        return winner == .white ? "1-0" : "0-1"
    }

    func pgn() -> String {
        var lines: [String] = []
        lines.append("[Event \"StockPlay rated game\"]")
        lines.append("[Site \"StockPlay for iOS\"]")
        lines.append("[Date \"\(Self.pgnDateFormatter.string(from: startDate))\"]")
        lines.append("[White \"\(playerColor == .white ? "Player" : Self.opponentName)\"]")
        lines.append("[Black \"\(playerColor == .black ? "Player" : Self.opponentName)\"]")
        lines.append("[Result \"\(resultString())\"]")
        lines.append("")
        lines.append(moveText)
        return lines.joined(separator: "\n")
    }

    private static let pgnDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
