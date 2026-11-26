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
    let badge: MoveBadge?
    let checkSquare: Square?
    let premove: PremoveVisual?
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
                // A queued premove drags its piece to the target, ghosted, until it is played.
                ForEach(pieces) { item in
                    let queued = premove.flatMap { visual -> Square? in
                        return visual.from == item.square ? visual.to : nil
                    }
                    pieceView(item.piece, size: cell)
                        .frame(width: cell, height: cell)
                        .position(center(of: queued ?? item.square, cell: cell))
                        .opacity(queued == nil ? 1 : 0.45)
                        .transition(.opacity)
                }
                .allowsHitTesting(false)

                // chess.com's verdict, in the corner of the square the move went to.
                if let badge = badge {
                    QualityMark(quality: badge.quality, size: cell * 0.40, showsCircle: true)
                        .position(badgePosition(for: badge.square, cell: cell))
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeOut(duration: 0.17), value: animationToken)
        .animation(.easeOut(duration: 0.17), value: premove)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: badge)
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

    /// The badge sits in the top corner of its square, inside the board.
    private func badgePosition(for square: Square, cell: CGFloat) -> CGPoint {
        let middle = center(of: square, cell: cell)
        return CGPoint(x: middle.x + cell * 0.28, y: middle.y - cell * 0.28)
    }

    // MARK: - Squares

    private func squareBackground(square: Square, size: CGFloat) -> some View {
        let isSelected = selected == square
        let isTarget = targets.contains(square)
        let isLastMove = lastMove.map { $0.from == square || $0.to == square } ?? false
        let hasPiece = board.piece(at: square) != nil
        let isCheck = checkSquare == square
        let isPremoveSquare = premove.map { $0.from == square || $0.to == square } ?? false

        return ZStack {
            Rectangle()
                .fill(square.isLight ? Theme.squareLight : Theme.squareDark)

            if isCheck {
                CheckGlow(size: size)
            }

            if isLastMove {
                Rectangle().fill(Theme.gold.opacity(0.30))
            }
            if isPremoveSquare {
                Rectangle().fill(Theme.gold.opacity(0.18))
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

/// The red wash chess.com puts behind a king that is in check: it breathes.
private struct CheckGlow: View {
    let size: CGFloat

    @State private var pulsing = false

    var body: some View {
        RadialGradient(
            colors: [
                Theme.checkGlow.opacity(0.92),
                Theme.checkGlow.opacity(0.42),
                Theme.checkGlow.opacity(0.0),
            ],
            center: .center,
            startRadius: 0,
            endRadius: size * 0.72
        )
        .scaleEffect(pulsing ? 1.06 : 0.92)
        .opacity(pulsing ? 1.0 : 0.62)
        .animation(
            .easeInOut(duration: 0.75).repeatForever(autoreverses: true),
            value: pulsing
        )
        .onAppear {
            pulsing = true
        }
        .allowsHitTesting(false)
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
