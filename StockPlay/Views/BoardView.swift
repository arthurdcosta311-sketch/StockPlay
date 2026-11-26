//
//  BoardView.swift
//  StockPlay
//
//  The board: ivory and slate squares, filled glyphs, last-move and legal-move hints.
//

import SwiftUI

struct BoardView: View {
    let board: ChessBoard
    let flipped: Bool
    let selected: Square?
    let targets: [Square]
    let lastMove: Move?
    let onTap: (Square) -> Void

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let cell = side / 8

            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { column in
                            let square = squareFor(row: row, column: column)
                            squareView(square: square, size: cell)
                                .frame(width: cell, height: cell)
                                .contentShape(Rectangle())
                                .onTapGesture { onTap(square) }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func squareFor(row: Int, column: Int) -> Square {
        if flipped {
            return Square(file: 7 - column, rank: row)
        }
        return Square(file: column, rank: 7 - row)
    }

    private func squareView(square: Square, size: CGFloat) -> some View {
        let piece = board.piece(at: square)
        let isSelected = selected == square
        let isTarget = targets.contains(square)
        let isLastMove = lastMove.map { $0.from == square || $0.to == square } ?? false

        return ZStack {
            Rectangle()
                .fill(square.isLight ? Theme.squareLight : Theme.squareDark)

            if isLastMove {
                Rectangle().fill(Theme.gold.opacity(0.30))
            }
            if isSelected {
                Rectangle().fill(Theme.gold.opacity(0.45))
            }

            if let piece = piece {
                pieceGlyph(piece, size: size)
            }

            if isTarget {
                if piece == nil {
                    Circle()
                        .fill(Theme.ink.opacity(0.26))
                        .frame(width: size * 0.24, height: size * 0.24)
                } else {
                    Circle()
                        .strokeBorder(Theme.ink.opacity(0.34), lineWidth: size * 0.07)
                        .frame(width: size * 0.88, height: size * 0.88)
                }
            }
        }
    }

    /// Ivory pieces carry a dark rim, black pieces a pale one, so both read on both squares.
    private func pieceGlyph(_ piece: Piece, size: CGFloat) -> some View {
        let glyphSize = size * 0.74
        let rim = max(1.0, size * 0.028)
        let fill = piece.color == .white ? Theme.ivory : Theme.ink
        let rimColor = piece.color == .white ? Theme.ink.opacity(0.92) : Theme.ivory.opacity(0.55)

        return ZStack {
            Text(piece.kind.glyph)
                .font(.system(size: glyphSize))
                .foregroundStyle(rimColor)
                .offset(x: -rim, y: 0)
            Text(piece.kind.glyph)
                .font(.system(size: glyphSize))
                .foregroundStyle(rimColor)
                .offset(x: rim, y: 0)
            Text(piece.kind.glyph)
                .font(.system(size: glyphSize))
                .foregroundStyle(rimColor)
                .offset(x: 0, y: -rim)
            Text(piece.kind.glyph)
                .font(.system(size: glyphSize))
                .foregroundStyle(rimColor)
                .offset(x: 0, y: rim)
            Text(piece.kind.glyph)
                .font(.system(size: glyphSize))
                .foregroundStyle(fill)
                .shadow(
                    color: .black.opacity(piece.color == .white ? 0.20 : 0.30),
                    radius: size * 0.015,
                    x: 0,
                    y: size * 0.012
                )
        }
    }
}
