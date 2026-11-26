//
//  Components.swift
//  StockPlay
//
//  Small shared pieces of UI.
//

import SwiftUI

/// A player's strip: avatar, name, title badge, rating and clock.
struct PlayerRow: View {
    let name: String
    let title: String?
    let subtitle: String
    let ratingText: String
    let glyph: String
    let clockText: String?
    let isActive: Bool
    let isEngine: Bool
    /// The pieces this player has taken from the other side.
    let captured: [PieceKind]
    /// The colour of those captured pieces.
    let capturedColor: ChessColor
    /// How many pawns this player is ahead by.
    let lead: Int

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(isEngine ? Theme.gold.opacity(0.14) : Theme.surfaceRaised)
                Circle()
                    .strokeBorder(isEngine ? Theme.gold.opacity(0.45) : Theme.hairline, lineWidth: 1)
                Text(glyph)
                    .font(.system(size: 28))
                    .foregroundStyle(isEngine ? Theme.ivory : Theme.textPrimary)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if let title = title {
                        Text(title)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Theme.gold, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                if !captured.isEmpty || lead > 0 {
                    HStack(spacing: 4) {
                        CapturedRow(pieces: captured, color: capturedColor)
                        if lead > 0 {
                            Text("+\(lead)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                Text(ratingText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? Theme.gold : Theme.textPrimary)
                if let clockText = clockText {
                    Text(clockText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isActive ? Theme.gold.opacity(0.45) : Theme.hairline, lineWidth: 1)
        )
    }
}

/// The little row of pieces one side has taken, the way chess.com shows them.
struct CapturedRow: View {
    let pieces: [PieceKind]
    let color: ChessColor

    var body: some View {
        HStack(spacing: 0.5) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, kind in
                Text(kind.outlineGlyph)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color == .white ? Theme.ivory.opacity(0.92) : Theme.textSecondary)
                    .shadow(color: .black.opacity(0.4), radius: 0.6, x: 0, y: 0.6)
            }
        }
    }
}

/// A caption above a group of controls.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(Theme.textSecondary)
    }
}

/// One number with a caption, used in the record strip.
struct StatColumn: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// chess.com's move mark: "!!", "!", "★", "✓", "?!", "?", "??", or a book for theory.
struct QualityMark: View {
    let quality: MoveQuality
    let size: CGFloat
    var showsCircle: Bool = false

    var body: some View {
        ZStack {
            if showsCircle {
                Circle()
                    .fill(Theme.background)
                Circle()
                    .strokeBorder(quality.color, lineWidth: max(1.4, size * 0.16))
            }

            if let mark = quality.boardMark {
                Text(mark)
                    .font(.system(size: size * (mark.count > 1 ? 0.62 : 0.84), weight: .heavy, design: .rounded))
                    .foregroundStyle(quality.color)
                    .minimumScaleFactor(0.4)
            } else {
                Image(systemName: quality.symbol)
                    .font(.system(size: size * 0.56, weight: .bold))
                    .foregroundStyle(quality.color)
            }
        }
        .frame(width: size, height: size)
    }
}

/// A selectable pill.
struct ChoicePill: View {
    let title: String
    let detail: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.ink.opacity(0.7) : Theme.textSecondary)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isSelected ? Theme.gold : Theme.surface)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
