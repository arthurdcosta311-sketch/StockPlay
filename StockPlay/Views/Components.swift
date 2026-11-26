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
