//
//  BoardView.swift
//  StockPlay
//
//  The board: ivory and slate squares, last-move and legal-move hints, and
//  pieces that slide between squares the way chess.com's do.
//

import SwiftUI

struct BoardView: View {
    let board: ChessBoard
    let pieces: [BoardPiece]
    let flipped: Bool
    let selected: Square?
    let targets: [Square]
    let lastMove: Move?
    let animationToken: Int
    let onTap: (Square) -> Void

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let cell = side / 8

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { column in
                                let square = squareFor(row: row, column: column)
                                squareBackground(square: square, size: cell)
                                    .frame(width: cell, height: cell)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTap(square) }
                            }
                        }
                    }
                }

                // Pieces ride above the squares on their own layer, so a move slides.
                ForEach(pieces) { item in
                    pieceView(item.piece, size: cell)
                        .frame(width: cell, height: cell)
                        .position(center(of: item.square, cell: cell))
                        .transition(.opacity)
                }
                .allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeOut(duration: 0.17), value: animationToken)
    }

    // MARK: - Geometry

    private func squareFor(row: Int, column: Int) -> Square {
        if flipped {
            return Square(file: 7 - column, rank: row)
        }
        return Square(file: column, rank: 7 - row)
    }

    private func center(of square: Square, cell: CGFloat) -> CGPoint {
        let column = flipped ? 7 - square.file : square.file
        let row = flipped ? square.rank : 7 - square.rank
        return CGPoint(x: (CGFloat(column) + 0.5) * cell, y: (CGFloat(row) + 0.5) * cell)
    }

    // MARK: - Squares

    private func squareBackground(square: Square, size: CGFloat) -> some View {
        let isSelected = selected == square
        let isTarget = targets.contains(square)
        let isLastMove = lastMove.map { $0.from == square || $0.to == square } ?? false
        let hasPiece = board.piece(at: square) != nil

        return ZStack {
            Rectangle()
                .fill(square.isLight ? Theme.squareLight : Theme.squareDark)

            if isLastMove {
                Rectangle().fill(Theme.gold.opacity(0.30))
            }
            if isSelected {
                Rectangle().fill(Theme.gold.opacity(0.45))
            }

            if isTarget {
                if hasPiece {
                    Circle()
                        .strokeBorder(Theme.ink.opacity(0.34), lineWidth: size * 0.07)
                        .frame(width: size * 0.88, height: size * 0.88)
                } else {
                    Circle()
                        .fill(Theme.ink.opacity(0.26))
                        .frame(width: size * 0.24, height: size * 0.24)
                }
            }
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func pieceView(_ piece: Piece, size: CGFloat) -> some View {
        if piece.kind == .pawn {
            pawnView(piece, size: size)
        } else {
            glyphView(piece, size: size)
        }
    }

    /// iOS draws the Unicode pawn (U+265F) as a colour emoji, which ignores any tint,
    /// so the pawn is drawn as a shape and takes the piece colour like the others.
    private func pawnView(_ piece: Piece, size: CGFloat) -> some View {
        let fill = piece.color == .white ? Theme.ivory : Theme.ink
        let rimColor = piece.color == .white ? Theme.ink.opacity(0.92) : Theme.ivory.opacity(0.55)
        let pawnSize = size * 0.86

        return ZStack {
            PawnSilhouette(size: pawnSize * 1.06)
                .foregroundStyle(rimColor)
            PawnSilhouette(size: pawnSize)
                .foregroundStyle(fill)
        }
        .frame(width: size, height: size)
        .shadow(
            color: .black.opacity(piece.color == .white ? 0.20 : 0.30),
            radius: size * 0.015,
            x: 0,
            y: size * 0.012
        )
    }

    /// The other pieces keep the font glyphs: ivory with a dark rim, black with a pale one.
    private func glyphView(_ piece: Piece, size: CGFloat) -> some View {
        let glyphSize = size * 0.74
        let rim = max(1.0, size * 0.028)
        let fill = piece.color == .white ? Theme.ivory : Theme.ink
        let rimColor = piece.color == .white ? Theme.ink.opacity(0.92) : Theme.ivory.opacity(0.55)

        return ZStack {
            Text(piece.kind.outlineGlyph)
                .font(.system(size: glyphSize))
                .foregroundStyle(piece.color == .white ? Theme.ink : Theme.ivory)
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

/// A pawn silhouette: head, collar, stem and base, sized to its frame.
private struct PawnSilhouette: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.030, style: .continuous)
                .frame(width: size * 0.46, height: size * 0.130)
                .offset(y: size * 0.225)

            Capsule(style: .continuous)
                .frame(width: size * 0.30, height: size * 0.075)
                .offset(y: size * 0.115)

            PawnBody()
                .frame(width: size * 0.38, height: size * 0.24)
                .offset(y: size * 0.010)

            Circle()
                .frame(width: size * 0.26, height: size * 0.26)
                .offset(y: size * -0.200)
        }
        .frame(width: size, height: size)
    }
}

/// The stem of the pawn: a trapezoid with gently curved sides.
private struct PawnBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: rect.minX + width * 0.22, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.05, y: rect.maxY),
            control1: CGPoint(x: rect.minX + width * 0.12, y: rect.minY + height * 0.45),
            control2: CGPoint(x: rect.minX + width * 0.01, y: rect.minY + height * 0.78)
        )
        path.addLine(to: CGPoint(x: rect.maxX - width * 0.05, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX - width * 0.22, y: rect.minY),
            control1: CGPoint(x: rect.maxX - width * 0.01, y: rect.minY + height * 0.78),
            control2: CGPoint(x: rect.maxX - width * 0.12, y: rect.minY + height * 0.45)
        )
        path.closeSubpath()
        return path
    }
}
