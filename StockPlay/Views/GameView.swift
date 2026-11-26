//
//  GameView.swift
//  StockPlay
//
//  The board, the clock, the grandmaster's replies and the way out.
//

import SwiftUI

struct GameView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var controller: GameController
    @State private var store = PlayerStore.shared
    @State private var showResignDialog = false
    @State private var showResult = false

    init(controller: GameController) {
        _controller = State(initialValue: controller)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 11) {
                topBar
                opponentBar
                boardArea
                infoRow
                playerBar
                moveStrip
                controls
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
        .task {
            controller.start()
        }
        .onChange(of: controller.phase) { _, phase in
            if phase == .finished {
                showResult = true
            }
        }
        .sheet(isPresented: $showResult) {
            GameOverView(controller: controller, onRematch: rematch, onDone: { dismiss() })
        }
        .confirmationDialog("Resign this game?", isPresented: $showResignDialog, titleVisibility: .visible) {
            Button("Resign", role: .destructive) {
                controller.resign()
            }
            Button("Keep playing", role: .cancel) { }
        } message: {
            Text("The grandmaster takes the point and your rating drops as a loss.")
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.surface, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("Rated game")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(controller.timeControl.shortLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                controller.toggleFlip()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.surface, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var opponentBar: some View {
        PlayerRow(
            name: GameController.opponentName,
            title: GameController.opponentTitle,
            subtitle: controller.isEngineThinking ? "Thinking…" : "Full strength",
            ratingText: String(GameController.opponentRating),
            glyph: PieceKind.knight.glyph,
            clockText: controller.clockText(for: controller.playerColor.opposite),
            isActive: controller.phase == .playing && controller.board.sideToMove != controller.playerColor,
            isEngine: true
        )
    }

    private var playerBar: some View {
        PlayerRow(
            name: "You",
            title: nil,
            subtitle: "\(controller.playerColor.name) pieces",
            ratingText: store.profile.ratingText,
            glyph: PieceKind.king.glyph,
            clockText: controller.clockText(for: controller.playerColor),
            isActive: controller.isPlayersTurn,
            isEngine: false
        )
    }

    private var boardArea: some View {
        BoardView(
            board: controller.board,
            flipped: controller.isBoardFlipped,
            selected: controller.selectedSquare,
            targets: controller.legalTargets,
            lastMove: controller.lastMove,
            onTap: { square in controller.handleTap(square) }
        )
        .frame(maxWidth: 520)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
        .frame(maxWidth: .infinity)
    }

    private var infoRow: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(controller.isPlayersTurn ? Theme.gold : Theme.textSecondary.opacity(0.55))
                .frame(width: 6, height: 6)
            Text(controller.statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("Move \(max(1, controller.board.fullmoveNumber))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary.opacity(0.75))
        }
        .frame(height: 18)
    }

    private var moveStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if controller.entries.isEmpty {
                    Text("No moves yet")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                }
                ForEach(controller.entries) { entry in
                    Text(entry.color == .white ? "\(entry.moveNumber). \(entry.san)" : entry.san)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(entry.color == controller.playerColor ? Theme.textPrimary : Theme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }
            .padding(.horizontal, 1)
        }
        .defaultScrollAnchor(.trailing)
        .frame(height: 30)
    }

    private var controls: some View {
        HStack(spacing: 9) {
            controlButton("Resign", "flag") {
                showResignDialog = true
            }
            controlButton("Undo", "arrow.uturn.backward") {
                controller.takeback()
            }
        }
    }

    private func controlButton(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rematch

    private func rematch() {
        showResult = false
        let fresh = GameController(playerColor: controller.playerColor, timeControl: controller.timeControl)
        controller = fresh
        fresh.start()
    }
}

#Preview {
    GameView(controller: GameController(playerColor: .white, timeControl: TimeControl.all[2]))
        .preferredColorScheme(.dark)
}
