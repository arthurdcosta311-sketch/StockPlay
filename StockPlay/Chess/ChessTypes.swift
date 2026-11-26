//
//  ChessTypes.swift
//  Grandmaster
//
//  The vocabulary of the game: colours, pieces, squares and moves.
//

import Foundation

enum ChessColor: String, Codable, Sendable, CaseIterable {
    case white
    case black

    var opposite: ChessColor {
        return self == .white ? .black : .white
    }

    var name: String {
        switch self {
        case .white: return "White"
        case .black: return "Black"
        }
    }

    /// A filled glyph used for both colours; only the tint changes.
    var kingGlyph: String {
        return "♚"
    }
}

enum PieceKind: String, Codable, Sendable, CaseIterable {
    case pawn
    case knight
    case bishop
    case rook
    case queen
    case king

    var letter: String {
        switch self {
        case .pawn: return "p"
        case .knight: return "n"
        case .bishop: return "b"
        case .rook: return "r"
        case .queen: return "q"
        case .king: return "k"
        }
    }

    var sanLetter: String {
        return self == .pawn ? "" : letter.uppercased()
    }

    init?(letter: String) {
        switch letter.lowercased() {
        case "p": self = .pawn
        case "n": self = .knight
        case "b": self = .bishop
        case "r": self = .rook
        case "q": self = .queen
        case "k": self = .king
        default: return nil
        }
    }

    /// Centipawn value used by the engine.
    var value: Int {
        switch self {
        case .pawn: return 100
        case .knight: return 320
        case .bishop: return 330
        case .rook: return 500
        case .queen: return 900
        case .king: return 0
        }
    }

    var displayName: String {
        switch self {
        case .pawn: return "Pawn"
        case .knight: return "Knight"
        case .bishop: return "Bishop"
        case .rook: return "Rook"
        case .queen: return "Queen"
        case .king: return "King"
        }
    }

    /// Filled Unicode glyph; the piece colour comes from the tint.
    var glyph: String {
        switch self {
        case .pawn: return "♟"
        case .knight: return "♞"
        case .bishop: return "♝"
        case .rook: return "♜"
        case .queen: return "♛"
        case .king: return "♚"
        }
    }

    /// Hollow version of the same piece, drawn under the filled glyph as a rim.
    var outlineGlyph: String {
        switch self {
        case .pawn: return "♙"
        case .knight: return "♘"
        case .bishop: return "♗"
        case .rook: return "♖"
        case .queen: return "♕"
        case .king: return "♔"
        }
    }
}

struct Piece: Hashable, Sendable, Codable {
    let color: ChessColor
    let kind: PieceKind

    var fenLetter: String {
        return color == .white ? kind.letter.uppercased() : kind.letter
    }
}

struct Square: Hashable, Sendable, Codable, Identifiable {
    /// 0...7 for the a...h file.
    let file: Int
    /// 0...7 for the 1...8 rank.
    let rank: Int

    init(file: Int, rank: Int) {
        self.file = file
        self.rank = rank
    }

    init?(index: Int) {
        guard (0..<64).contains(index) else { return nil }
        self.file = index % 8
        self.rank = index / 8
    }

    /// Parses algebraic coordinates such as "e4".
    init?(_ name: String) {
        let characters = Array(name.lowercased())
        guard characters.count == 2,
              let ascii = characters[0].asciiValue,
              let fileIndex = Int(String(characters[1])).map({ $0 - 1 }) else { return nil }
        let fileValue = Int(ascii) - 97
        guard (0..<8).contains(fileValue), (0..<8).contains(fileIndex) else { return nil }
        self.init(file: fileValue, rank: fileIndex)
    }

    var id: Int { return rank * 8 + file }

    var index: Int { return rank * 8 + file }

    var name: String {
        let fileLetter = String(UnicodeScalar(UInt8(97 + file)))
        return fileLetter + String(rank + 1)
    }

    var isLight: Bool {
        return (file + rank) % 2 == 1
    }

    var fileLetter: String {
        return String(UnicodeScalar(UInt8(97 + file)))
    }

    static let all: [Square] = (0..<64).compactMap { Square(index: $0) }
}

struct Move: Hashable, Sendable {
    let from: Square
    let to: Square
    var promotion: PieceKind? = nil
    var isEnPassant: Bool = false
    var isCastling: Bool = false

    /// Long algebraic notation, as the engine speaks it ("e2e4", "e7e8q").
    var uci: String {
        var text = from.name + to.name
        if let promotion = promotion {
            text += promotion.letter
        }
        return text
    }
}
