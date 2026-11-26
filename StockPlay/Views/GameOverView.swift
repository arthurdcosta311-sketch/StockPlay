//
//  GameOverView.swift
//  StockPlay
//
//  The result, and what it did to your rating.
//

import SwiftUI

struct GameOverView: View {
    let controller: GameController
    let onRematch: () -> Void
    let onDone: () -> Void

    @State private var store = PlayerStore.shared
    @State private var showReview = false

    private var outcome: GameOutcome {
        return controller.end?.outcome(for: controller.playerColor) ?? .draw
    }

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                icon
                    .padding(.top, 26)

                VStack(spacing: 7) {
                    Text(outcome.title)
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.textPrimary)
                    Text(controller.end?.playerReason(for: controller.playerColor) ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 16)

                ratingCard
                    .padding(.top, 22)

                Spacer(minLength: 16)

                Button {
                    showReview = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Game review")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.surfaceRaised, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: onRematch) {
                    Text("Rematch")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.gold, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showReview) {
            ReviewView(controller: controller)
        }
        .presentationDetents([.height(470)])
        .presentationBackground(Theme.surface)
        .interactiveDismissDisabled()
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(Theme.gold.opacity(0.12))
            Circle()
                .strokeBorder(Theme.gold.opacity(0.40), lineWidth: 1)
            Image(systemName: symbolName)
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(outcome == .win ? Theme.gold : Theme.textSecondary)
        }
        .frame(width: 74, height: 74)
    }

    private var symbolName: String {
        switch outcome {
        case .win: return "crown.fill"
        case .loss: return "flag.fill"
        case .draw: return "equal.circle.fill"
        }
    }

    private var ratingCard: some View {
        VStack(spacing: 12) {
            HStack {
                SectionLabel(text: "RATING")
                Spacer()
                if let change = controller.ratingChange {
                    Text(change.deltaText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(change.delta > 0 ? Theme.win : (change.delta < 0 ? Theme.loss : Theme.textSecondary))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Theme.background, in: Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 9) {
                if let change = controller.ratingChange {
                    Text("\(change.before)")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(change.after)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Text(store.profile.ratingText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}
