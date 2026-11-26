//
//  ChessBoard.swift
//  Grandmaster
//
//  A complete, immutable-style chess position: rules, legal moves, SAN and FEN.
//

import Foundation

struct CastlingRights: Hashable, Sendable {
    var whiteKingside = false
    var whiteQueenside = false
    var blackKingside = false
    var blackQueenside = false

    static let none = CastlingRights()
    static let all = CastlingRights(whiteKingside: true, whiteQueenside: true, blackKingside: true, blackQueenside: true)

    var fenField: String {
        var text = ""
        if whiteKingside { text += "K" }
        if whiteQueenside { text += "Q" }
        if blackKingside { text += "k" }
        if blackQueenside { text += "q" }
        return text.isEmpty ? "-" : text
    }
}

enum GameOutcome: String, Codable, Sendable {
    case win
    case loss
    case draw

    /// The score the player earned, as Elo sees it.
    var score: Double {
        switch self {
        case .win: return 1.0
        case .draw: return 0.5
        case .loss: return 0.0
        }
    }

    var title: String {
        switch self {
        case .win: return "You won"
        case .loss: return "You lost"
        case .draw: return "Draw"
        }
    }

    var shortTitle: String {
        switch self {
        case .win: return "Win"
        case .loss: return "Loss"
        case .draw: return "Draw"
        }
    }
}

enum GameEnd: Equatable, Sendable {
    case checkmate(winner: ChessColor)
    case stalemate
    case insufficientMaterial
    case fiftyMoveRule
    case threefoldRepetition
    case timeout(winner: ChessColor)
    case resignation(winner: ChessColor)

    var winner: ChessColor? {
        switch self {
        case let .checkmate(winner): return winner
        case let .timeout(winner): return winner
        case let .resignation(winner): return winner
        default: return nil
        }
    }

    func outcome(for color: ChessColor) -> GameOutcome {
        guard let winner = winner else { return .draw }
        return winner == color ? .win : .loss
    }

    var reason: String {
        switch self {
        case let .checkmate(winner):
            return winner == .white ? "Checkmate — White wins" : "Checkmate — Black wins"
        case .stalemate:
            return "Stalemate — no legal moves, no check"
        case .insufficientMaterial:
            return "Draw by insufficient material"
        case .fiftyMoveRule:
            return "Draw by the fifty-move rule"
        case .threefoldRepetition:
            return "Draw by threefold repetition"
        case let .timeout(winner):
            return "Time out — \(winner.name) wins on the clock"
        case let .resignation(winner):
            return "Resignation — \(winner.name) wins"
        }
    }

    /// The reason line, from the player's point of view.
    func playerReason(for color: ChessColor) -> String {
        switch self {
        case let .checkmate(winner):
            return winner == color ? "You delivered checkmate" : "Your king was checkmated"
        case .stalemate:
            return "Stalemate — no legal moves, no check"
        case .insufficientMaterial:
            return "Neither side can force a mate"
        case .fiftyMoveRule:
            return "Fifty moves without a pawn move or a capture"
        case .threefoldRepetition:
            return "The same position appeared three times"
        case let .timeout(winner):
            return winner == color ? "Your opponent ran out of time" : "Your flag fell"
        case let .resignation(winner):
            return winner == color ? "Your opponent resigned" : "You resigned"
        }
    }
}

struct ChessBoard: Sendable {
    var squares: [Piece?]
    var sideToMove: ChessColor
    var castling: CastlingRights
    var enPassant: Square?
    var halfmoveClock: Int
    var fullmoveNumber: Int

    init(
        squares: [Piece?],
        sideToMove: ChessColor = .white,
        castling: CastlingRights = .none,
        enPassant: Square? = nil,
        halfmoveClock: Int = 0,
        fullmoveNumber: Int = 1
    ) {
        self.squares = squares
        self.sideToMove = sideToMove
        self.castling = castling
        self.enPassant = enPassant
        self.halfmoveClock = halfmoveClock
        self.fullmoveNumber = fullmoveNumber
    }

    static let initial: ChessBoard = {
        var board = ChessBoard(squares: Array(repeating: nil, count: 64), castling: .all)
        for file in 0..<8 {
            board.squares[Square(file: file, rank: 1).index] = Piece(color: .white, kind: .pawn)
            board.squares[Square(file: file, rank: 6).index] = Piece(color: .black, kind: .pawn)
        }
        let backRank: [PieceKind] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for (file, kind) in backRank.enumerated() {
            board.squares[Square(file: file, rank: 0).index] = Piece(color: .white, kind: kind)
            board.squares[Square(file: file, rank: 7).index] = Piece(color: .black, kind: kind)
        }
        return board
    }()

    /// FEN, as every chess program reads and writes positions.
    init?(fen: String) {
        let fields = fen.split(separator: " ").map(String.init)
        guard fields.count >= 4 else { return nil }

        var board = Array<Piece?>(repeating: nil, count: 64)
        let ranks = fields[0].split(separator: "/", omittingEmptySubsequences: false)
        guard ranks.count == 8 else { return nil }

        for (row, rankText) in ranks.enumerated() {
            let rank = 7 - row
            var file = 0
            for character in rankText {
                if let empty = character.wholeNumberValue {
                    file += empty
                    continue
                }
                guard file < 8, let kind = PieceKind(letter: String(character)) else { return nil }
                let color: ChessColor = character.isUppercase ? .white : .black
                board[rank * 8 + file] = Piece(color: color, kind: kind)
                file += 1
            }
            guard file == 8 else { return nil }
        }

        var rights = CastlingRights.none
        if fields[2].contains("K") { rights.whiteKingside = true }
        if fields[2].contains("Q") { rights.whiteQueenside = true }
        if fields[2].contains("k") { rights.blackKingside = true }
        if fields[2].contains("q") { rights.blackQueenside = true }

        squares = board
        sideToMove = fields[1].hasPrefix("b") ? .black : .white
        castling = rights
        enPassant = fields[3] == "-" ? nil : Square(fields[3])
        halfmoveClock = fields.count > 4 ? (Int(fields[4]) ?? 0) : 0
        fullmoveNumber = fields.count > 5 ? (Int(fields[5]) ?? 1) : 1
    }

    var fen: String {
        var rows: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var row = ""
            var empty = 0
            for file in 0..<8 {
                if let piece = squares[rank * 8 + file] {
                    if empty > 0 {
                        row += String(empty)
                        empty = 0
                    }
                    row += piece.fenLetter
                } else {
                    empty += 1
                }
            }
            if empty > 0 {
                row += String(empty)
            }
            rows.append(row)
        }
        let placement = rows.joined(separator: "/")
        let side = sideToMove == .white ? "w" : "b"
        let ep = enPassant?.name ?? "-"
        return "\(placement) \(side) \(castling.fenField) \(ep) \(halfmoveClock) \(fullmoveNumber)"
    }

    /// FEN without the clocks: two equal keys mean the same position for repetition.
    var positionKey: String {
        let fields = fen.split(separator: " ")
        return fields.prefix(4).joined(separator: " ")
    }

    // MARK: - Access

    func isValid(_ square: Square) -> Bool {
        return (0..<8).contains(square.file) && (0..<8).contains(square.rank)
    }

    func piece(at square: Square) -> Piece? {
        guard isValid(square) else { return nil }
        return squares[square.index]
    }

    func kingSquare(for color: ChessColor) -> Square? {
        for index in 0..<64 {
            if let piece = squares[index], piece.kind == .king, piece.color == color {
                return Square(index: index)
            }
        }
        return nil
    }

    func isInCheck(_ color: ChessColor) -> Bool {
        guard let king = kingSquare(for: color) else { return false }
        return isAttacked(king, by: color.opposite)
    }

    var isInCheck: Bool {
        return isInCheck(sideToMove)
    }

    /// True when one of `color`'s pieces attacks `square`.
    func isAttacked(_ square: Square, by color: ChessColor) -> Bool {
        // Pawns attack diagonally forward.
        let pawnRank = square.rank - (color == .white ? 1 : -1)
        for fileOffset in [-1, 1] {
            let file = square.file + fileOffset
            guard (0..<8).contains(file), (0..<8).contains(pawnRank) else { continue }
            if let piece = squares[pawnRank * 8 + file], piece.color == color, piece.kind == .pawn {
                return true
            }
        }

        // Knights.
        for offset in ChessBoard.knightOffsets {
            let file = square.file + offset.0
            let rank = square.rank + offset.1
            guard (0..<8).contains(file), (0..<8).contains(rank) else { continue }
            if let piece = squares[rank * 8 + file], piece.color == color, piece.kind == .knight {
                return true
            }
        }

        // King.
        for offset in ChessBoard.kingOffsets {
            let file = square.file + offset.0
            let rank = square.rank + offset.1
            guard (0..<8).contains(file), (0..<8).contains(rank) else { continue }
            if let piece = squares[rank * 8 + file], piece.color == color, piece.kind == .king {
                return true
            }
        }

        // Rooks and queens along ranks and files.
        for direction in ChessBoard.rookDirections {
            var file = square.file + direction.0
            var rank = square.rank + direction.1
            while (0..<8).contains(file), (0..<8).contains(rank) {
                if let piece = squares[rank * 8 + file] {
                    if piece.color == color, piece.kind == .rook || piece.kind == .queen {
                        return true
                    }
                    break
                }
                file += direction.0
                rank += direction.1
            }
        }

        // Bishops and queens along diagonals.
        for direction in ChessBoard.bishopDirections {
            var file = square.file + direction.0
            var rank = square.rank + direction.1
            while (0..<8).contains(file), (0..<8).contains(rank) {
                if let piece = squares[rank * 8 + file] {
                    if piece.color == color, piece.kind == .bishop || piece.kind == .queen {
                        return true
                    }
                    break
                }
                file += direction.0
                rank += direction.1
            }
        }

        return false
    }

    // MARK: - Move generation

    static let knightOffsets: [(Int, Int)] = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    static let kingOffsets: [(Int, Int)] = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
    static let rookDirections: [(Int, Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    static let bishopDirections: [(Int, Int)] = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    static let queenDirections: [(Int, Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)]

    var legalMoves: [Move] {
        return legalMoves(for: sideToMove)
    }

    func legalMoves(for color: ChessColor) -> [Move] {
        let pseudo = pseudoLegalMoves(for: color)
        var moves: [Move] = []
        moves.reserveCapacity(pseudo.count)
        for move in pseudo {
            let next = applying(move)
            guard let king = next.kingSquare(for: color) else {
                moves.append(move)
                continue
            }
            if !next.isAttacked(king, by: color.opposite) {
                moves.append(move)
            }
        }
        return moves
    }

    func pseudoLegalMoves(for color: ChessColor) -> [Move] {
        var moves: [Move] = []
        for index in 0..<64 {
            guard let piece = squares[index], piece.color == color, let from = Square(index: index) else { continue }
            switch piece.kind {
            case .pawn:
                moves.append(contentsOf: pawnMoves(from: from, color: color))
            case .knight:
                moves.append(contentsOf: stepMoves(from: from, color: color, offsets: ChessBoard.knightOffsets))
            case .bishop:
                moves.append(contentsOf: slidingMoves(from: from, color: color, directions: ChessBoard.bishopDirections))
            case .rook:
                moves.append(contentsOf: slidingMoves(from: from, color: color, directions: ChessBoard.rookDirections))
            case .queen:
                moves.append(contentsOf: slidingMoves(from: from, color: color, directions: ChessBoard.queenDirections))
            case .king:
                moves.append(contentsOf: stepMoves(from: from, color: color, offsets: ChessBoard.kingOffsets))
                moves.append(contentsOf: castlingMoves(for: color))
            }
        }
        return moves
    }

    private func pawnMoves(from: Square, color: ChessColor) -> [Move] {
        var moves: [Move] = []
        let direction = color == .white ? 1 : -1
        let homeRank = color == .white ? 1 : 6
        let lastRank = color == .white ? 7 : 0

        let single = Square(file: from.file, rank: from.rank + direction)
        if isValid(single), squares[single.index] == nil {
            if single.rank == lastRank {
                moves.append(contentsOf: promotions(from: from, to: single))
            } else {
                moves.append(Move(from: from, to: single))
                let double = Square(file: from.file, rank: from.rank + 2 * direction)
                if from.rank == homeRank, isValid(double), squares[double.index] == nil {
                    moves.append(Move(from: from, to: double))
                }
            }
        }

        for fileOffset in [-1, 1] {
            let target = Square(file: from.file + fileOffset, rank: from.rank + direction)
            guard isValid(target) else { continue }
            if let piece = squares[target.index] {
                if piece.color != color {
                    if target.rank == lastRank {
                        moves.append(contentsOf: promotions(from: from, to: target))
                    } else {
                        moves.append(Move(from: from, to: target))
                    }
                }
            } else if let enPassant = enPassant, enPassant == target {
                moves.append(Move(from: from, to: target, isEnPassant: true))
            }
        }
        return moves
    }

    private func promotions(from: Square, to: Square) -> [Move] {
        return [.queen, .rook, .bishop, .knight].map { Move(from: from, to: to, promotion: $0) }
    }

    private func stepMoves(from: Square, color: ChessColor, offsets: [(Int, Int)]) -> [Move] {
        var moves: [Move] = []
        for offset in offsets {
            let to = Square(file: from.file + offset.0, rank: from.rank + offset.1)
            guard isValid(to) else { continue }
            if let piece = squares[to.index] {
                if piece.color != color {
                    moves.append(Move(from: from, to: to))
                }
            } else {
                moves.append(Move(from: from, to: to))
            }
        }
        return moves
    }

    private func slidingMoves(from: Square, color: ChessColor, directions: [(Int, Int)]) -> [Move] {
        var moves: [Move] = []
        for direction in directions {
            var file = from.file + direction.0
            var rank = from.rank + direction.1
            while (0..<8).contains(file), (0..<8).contains(rank) {
                let to = Square(file: file, rank: rank)
                if let piece = squares[to.index] {
                    if piece.color != color {
                        moves.append(Move(from: from, to: to))
                    }
                    break
                }
                moves.append(Move(from: from, to: to))
                file += direction.0
                rank += direction.1
            }
        }
        return moves
    }

    private func castlingMoves(for color: ChessColor) -> [Move] {
        let rank = color == .white ? 0 : 7
        let kingFrom = Square(file: 4, rank: rank)
        guard let king = squares[kingFrom.index], king.kind == .king, king.color == color else { return [] }
        guard !isAttacked(kingFrom, by: color.opposite) else { return [] }

        var moves: [Move] = []
        let kingsideRight = color == .white ? castling.whiteKingside : castling.blackKingside
        let queensideRight = color == .white ? castling.whiteQueenside : castling.blackQueenside

        if kingsideRight {
            let f = Square(file: 5, rank: rank)
            let g = Square(file: 6, rank: rank)
            let rook = squares[Square(file: 7, rank: rank).index]
            if squares[f.index] == nil, squares[g.index] == nil,
               let rook = rook, rook.kind == .rook, rook.color == color,
               !isAttacked(f, by: color.opposite), !isAttacked(g, by: color.opposite) {
                moves.append(Move(from: kingFrom, to: g, isCastling: true))
            }
        }

        if queensideRight {
            let b = Square(file: 1, rank: rank)
            let c = Square(file: 2, rank: rank)
            let d = Square(file: 3, rank: rank)
            let rook = squares[Square(file: 0, rank: rank).index]
            if squares[b.index] == nil, squares[c.index] == nil, squares[d.index] == nil,
               let rook = rook, rook.kind == .rook, rook.color == color,
               !isAttacked(d, by: color.opposite), !isAttacked(c, by: color.opposite) {
                moves.append(Move(from: kingFrom, to: c, isCastling: true))
            }
        }

        return moves
    }

    // MARK: - Making moves

    func applying(_ move: Move) -> ChessBoard {
        var next = self
        let movingColor = squares[move.from.index]?.color ?? sideToMove
        let movingPiece = squares[move.from.index]
        let capturedSquare = move.isEnPassant ? Square(file: move.to.file, rank: move.from.rank) : move.to
        let capturedPiece = squares[capturedSquare.index]

        next.enPassant = nil
        next.squares[move.from.index] = nil
        if move.isEnPassant {
            next.squares[capturedSquare.index] = nil
        }

        if move.isCastling {
            let rank = move.from.rank
            let kingside = move.to.file == 6
            let rookFrom = Square(file: kingside ? 7 : 0, rank: rank)
            let rookTo = Square(file: kingside ? 5 : 3, rank: rank)
            next.squares[rookTo.index] = next.squares[rookFrom.index]
            next.squares[rookFrom.index] = nil
        }

        var placedPiece = movingPiece
        if let promotion = move.promotion {
            placedPiece = Piece(color: movingColor, kind: promotion)
        }
        next.squares[move.to.index] = placedPiece

        if let movingPiece = movingPiece {
            if movingPiece.kind == .king {
                next.clearKingsideRights(for: movingColor)
            } else if movingPiece.kind == .rook {
                next.clearRookRight(at: move.from)
            }
        }
        if let capturedPiece = capturedPiece, capturedPiece.kind == .rook {
            next.clearRookRight(at: capturedSquare)
        }

        if let placedPiece = placedPiece, placedPiece.kind == .pawn,
           abs(move.to.rank - move.from.rank) == 2 {
            let middleRank = (move.from.rank + move.to.rank) / 2
            next.enPassant = Square(file: move.from.file, rank: middleRank)
        }

        let isCapture = capturedPiece != nil
        if placedPiece?.kind == .pawn || isCapture {
            next.halfmoveClock = 0
        } else {
            next.halfmoveClock += 1
        }

        if movingColor == .black {
            next.fullmoveNumber += 1
        }
        next.sideToMove = movingColor.opposite
        return next
    }

    private mutating func clearKingsideRights(for color: ChessColor) {
        if color == .white {
            castling.whiteKingside = false
            castling.whiteQueenside = false
        } else {
            castling.blackKingside = false
            castling.blackQueenside = false
        }
    }

    private mutating func clearRookRight(at square: Square) {
        switch (square.file, square.rank) {
        case (0, 0):
            castling.whiteQueenside = false
        case (7, 0):
            castling.whiteKingside = false
        case (0, 7):
            castling.blackQueenside = false
        case (7, 7):
            castling.blackKingside = false
        default:
            break
        }
    }

    // MARK: - Notation

    /// Standard algebraic notation for one of this position's legal moves.
    func san(for move: Move) -> String {
        guard let piece = squares[move.from.index] else { return move.uci }

        var text: String
        if move.isCastling {
            text = move.to.file > move.from.file ? "O-O" : "O-O-O"
        } else if let promotion = move.promotion {
            let isCapture = squares[move.to.index] != nil || move.isEnPassant
            text = (isCapture ? move.from.fileLetter + "x" : "") + move.to.name + "=" + promotion.letter.uppercased()
        } else if piece.kind == .pawn {
            let isCapture = squares[move.to.index] != nil || move.isEnPassant
            text = isCapture ? move.from.fileLetter + "x" + move.to.name : move.to.name
        } else {
            let isCapture = squares[move.to.index] != nil
            text = piece.kind.sanLetter + disambiguation(for: move) + (isCapture ? "x" : "") + move.to.name
        }

        let next = applying(move)
        if next.isInCheck(next.sideToMove) {
            text += next.legalMoves.isEmpty ? "#" : "+"
        }
        return text
    }

    private func disambiguation(for move: Move) -> String {
        guard let piece = squares[move.from.index] else { return "" }
        let others = legalMoves.filter { other in
            other.from != move.from && other.to == move.to && squares[other.from.index]?.kind == piece.kind
        }
        guard !others.isEmpty else { return "" }
        let sharesFile = others.contains { $0.from.file == move.from.file }
        let sharesRank = others.contains { $0.from.rank == move.from.rank }
        if !sharesFile { return move.from.fileLetter }
        if !sharesRank { return String(move.from.rank + 1) }
        return move.from.name
    }

    // MARK: - Results

    var hasInsufficientMaterial: Bool {
        var knights = 0
        var bishops = 0
        var heavyPieces = 0
        var bishopSquareShades = Set<Bool>()

        for index in 0..<64 {
            guard let piece = squares[index] else { continue }
            switch piece.kind {
            case .pawn, .rook, .queen:
                heavyPieces += 1
            case .knight:
                knights += 1
            case .bishop:
                bishops += 1
                if let square = Square(index: index) {
                    bishopSquareShades.insert(square.isLight)
                }
            case .king:
                break
            }
        }

        if heavyPieces > 0 { return false }
        if bishops == 0 && knights <= 2 { return true }
        if bishops == 1 && knights == 0 { return true }
        if bishops == 2 && knights == 0 && bishopSquareShades.count == 1 { return true }
        return false
    }

    /// The game is over when this is non-nil. `repetitions` counts how often this position has occurred.
    func gameEnd(repetitions: Int) -> GameEnd? {
        if legalMoves.isEmpty {
            return isInCheck(sideToMove) ? .checkmate(winner: sideToMove.opposite) : .stalemate
        }
        if halfmoveClock >= 100 { return .fiftyMoveRule }
        if repetitions >= 3 { return .threefoldRepetition }
        if hasInsufficientMaterial { return .insufficientMaterial }
        return nil
    }
}
