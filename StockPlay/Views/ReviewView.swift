//
//  ReviewView.swift
//  StockPlay
//
//  The game review: accuracy, the verdict on every move, and what you should have played.
//

import SwiftUI

struct ReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let controller: GameController

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.surface.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if let review = controller.review {
                            summary(review)
                            moveList(review)
                            legend
                        } else {
                            progress
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Game review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .presentationBackground(Theme.surface)
        .task {
            controller.startReview()
        }
    }

    // MARK: - Progress

    private var progress: some View {
        VStack(spacing: 14) {
            Text("\(Int(controller.reviewProgress * 100))%")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            ProgressView(value: controller.reviewProgress)
                .tint(Theme.gold)
            Text("Stockfish is going through every move and finding what you should have played.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 60)
        .padding(.horizontal, 12)
    }

    // MARK: - Summary

    private func summary(_ review: GameReview) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                accuracyRing(review.playerAccuracy)

                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR ACCURACY")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(review.playerAccuracy)%")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Stockfish played at \(review.engineAccuracy)%")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(MoveQuality.allCases) { quality in
                    let count = review.playerCounts[quality] ?? 0
                    if count > 0 {
                        qualityChip(quality: quality, count: count)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func accuracyRing(_ accuracy: Int) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceRaised, lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, accuracy))) / 100)
                .stroke(Theme.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(accuracy)")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(width: 72, height: 72)
    }

    private func qualityChip(quality: MoveQuality, count: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: quality.symbol)
                .font(.system(size: 10, weight: .bold))
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(quality.title)
                .font(.system(size: 10))
                .lineLimit(1)
        }
        .foregroundStyle(quality.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(quality.color.opacity(0.12), in: Capsule())
    }

    // MARK: - Moves

    private func moveList(_ review: GameReview) -> some View {
        VStack(spacing: 5) {
            ForEach(review.items) { item in
                HStack(spacing: 9) {
                    Text(item.color == .white ? "\(item.moveNumber)." : "")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 20, alignment: .trailing)

                    Image(systemName: item.quality.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(item.quality.color)
                        .frame(width: 15)

                    Text(item.san)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(minWidth: 46, alignment: .leading)

                    if let best = item.bestSAN, !item.quality.isPraise {
                        Text("best \(best)")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.gold.opacity(0.9))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if item.color == review.playerColor, !item.quality.isPraise {
                        Text(item.quality.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(item.quality.color)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT THE MARKS MEAN")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary)

            ForEach(MoveQuality.allCases) { quality in
                HStack(spacing: 8) {
                    Image(systemName: quality.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(quality.color)
                        .frame(width: 15)
                    Text(quality.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 78, alignment: .leading)
                    Text(quality.explanation)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .background(Theme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
