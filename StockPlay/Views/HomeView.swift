//
//  HomeView.swift
//  StockPlay
//
//  The lobby: the grandmaster, your rating, colour and clock, then play.
//

import SwiftUI

struct HomeView: View {
    @State private var store = PlayerStore.shared
    @State private var stockfish = StockfishService.shared
    @State private var playerColor: ChessColor = .white
    @State private var timeControl: TimeControl = TimeControl.all[2]
    @State private var game: GameController?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    opponentCard
                    engineStatusRow
                    playerCard
                    setup
                    playButton
                    recentGames
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
        }
        .fullScreenCover(item: $game) { controller in
            GameView(controller: controller)
        }
        .task {
            StockfishService.shared.prepare()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("STOCKPLAY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3.4)
                    .foregroundStyle(Theme.gold)
                Text("Play the grandmaster")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer(minLength: 0)
            ratingPill
        }
    }

    private var ratingPill: some View {
        VStack(spacing: 2) {
            Text(store.profile.ratingText)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
            Text("YOUR ELO")
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - The opponent

    private var opponentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 15) {
                ZStack {
                    Circle().fill(Theme.gold.opacity(0.12))
                    Circle().strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1)
                    Text(PieceKind.knight.glyph)
                        .font(.system(size: 38))
                        .foregroundStyle(Theme.ivory)
                }
                .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(GameController.opponentName)
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundStyle(Theme.textPrimary)
                        Text(GameController.opponentTitle)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.gold, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    Text("\(GameController.opponentRating) Elo · full strength")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                    Text("Every move is searched as deeply as the phone allows.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)

            HStack(spacing: 0) {
                StatColumn(value: "\(store.profile.games)", label: "Games")
                divider
                StatColumn(value: "\(store.profile.wins)", label: "Wins")
                divider
                StatColumn(value: "\(store.profile.draws)", label: "Draws")
                divider
                StatColumn(value: "\(store.profile.losses)", label: "Losses")
            }
        }
        .padding(17)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 26)
    }

    private var engineStatusRow: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(engineStatusColor)
                .frame(width: 6, height: 6)
            Text(stockfish.statusText)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var engineStatusColor: Color {
        switch stockfish.state {
        case .ready: return Theme.win
        case .unavailable: return Theme.loss
        default: return Theme.gold
        }
    }

    // MARK: - The player

    private var playerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.surfaceRaised)
                Circle().strokeBorder(Theme.hairline, lineWidth: 1)
                Text(PieceKind.king.glyph)
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                Text("You")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(recordSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Text(store.profile.ratingText)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.gold)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var recordSummary: String {
        if store.profile.games == 0 {
            return store.profile.isProvisional ? "New account — playing your first rated games" : "No games played yet"
        }
        return "Peak \(store.profile.peakRating) · \(store.profile.games) rated games"
    }

    // MARK: - Setup

    private var setup: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(text: "PLAY AS")

            HStack(spacing: 10) {
                ForEach(ChessColor.allCases, id: \.self) { color in
                    colorButton(color)
                }
            }

            SectionLabel(text: "TIME CONTROL")
                .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(TimeControl.all) { control in
                        ChoicePill(
                            title: control.label,
                            detail: nil,
                            isSelected: control == timeControl
                        ) {
                            timeControl = control
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func colorButton(_ color: ChessColor) -> some View {
        let isSelected = playerColor == color
        return Button {
            playerColor = color
        } label: {
            HStack(spacing: 7) {
                Text(color == .white ? "♔" : "♚")
                    .font(.system(size: 16))
                Text(color.name)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Theme.ink : Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Theme.gold : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Play

    private var playButton: some View {
        Button {
            startGame()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("Play")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.gold, in: Capsule())
            .shadow(color: Theme.gold.opacity(0.25), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func startGame() {
        let controller = GameController(playerColor: playerColor, timeControl: timeControl)
        game = controller
    }

    // MARK: - History

    @ViewBuilder
    private var recentGames: some View {
        if !store.profile.history.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "RECENT GAMES")
                VStack(spacing: 8) {
                    ForEach(store.profile.history.prefix(3)) { record in
                        gameRow(record)
                    }
                }
            }
        }
    }

    private func gameRow(_ record: GameRecord) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.color(for: record.outcome))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.outcome.shortTitle) · \(record.playerColor.name) · \(record.moveCount) moves")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(record.reason)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(record.deltaText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(record.delta > 0 ? Theme.win : (record.delta < 0 ? Theme.loss : Theme.textSecondary))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var footer: some View {
        Text("Ratings use the Elo formula — K 40 while provisional, then 24. Beating the grandmaster pays in full; losing barely costs a point.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
