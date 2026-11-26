//
//  SacrificeOverlay.swift
//  StockPlay
//
//  The easter egg: a rook or a bishop given away for a cheaper piece gets its
//  picture and its shout, and winning after one gets its own portrait.
//

import SwiftUI
import UIKit

enum SacrificePiece: String, Sendable {
    case rook
    case bishop

    var shout: String {
        switch self {
        case .rook: return "THE ROOOOOOOKKK"
        case .bishop: return "THE BISHHOOOPPPP"
        }
    }

    var glyph: String {
        switch self {
        case .rook: return PieceKind.rook.glyph
        case .bishop: return PieceKind.bishop.glyph
        }
    }

    var title: String {
        switch self {
        case .rook: return "Rook sacrifice"
        case .bishop: return "Bishop sacrifice"
        }
    }

    /// The word its picture is expected to carry in its file name.
    var pictureKeyword: String {
        switch self {
        case .rook: return "rook"
        case .bishop: return "bishop"
        }
    }

    var pictureNames: [String] {
        switch self {
        case .rook: return ["TheRook", "RookMeme"]
        case .bishop: return ["TheBishop", "BishopMeme"]
        }
    }

    /// The portrait shown when the sacrifice wins the game.
    var victoryNames: [String] {
        switch self {
        case .rook: return ["Levy", "ChessLive"]
        case .bishop: return ["Magnus"]
        }
    }

    var victoryKeyword: String {
        switch self {
        case .rook: return "levy"
        case .bishop: return "magnus"
        }
    }
}

enum SacrificeArtwork {
    private static var cache: [String: UIImage] = [:]
    private static var tried = Set<String>()

    static func image(names: [String], keyword: String) -> UIImage? {
        guard let key = names.first else { return nil }
        if let cached = cache[key] { return cached }
        if tried.contains(key) { return nil }

        let image = load(names: names, keyword: keyword)
        tried.insert(key)
        if let image = image {
            cache[key] = image
        }
        return image
    }

    private static func load(names: [String], keyword: String) -> UIImage? {
        // An asset catalog entry with one of the names.
        for name in names {
            if let image = UIImage(named: name) {
                return image
            }
        }

        let extensions = ["png", "jpg", "jpeg", "webp", "heic"]

        // A file added to the app's folder, again by name.
        for name in names {
            for ext in extensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext),
                   let image = UIImage(contentsOfFile: url.path) {
                    return image
                }
            }
        }

        // Otherwise any picture whose file name mentions it.
        var loose: [URL] = []
        for ext in extensions {
            loose.append(contentsOf: Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [])
        }

        if let named = loose.first(where: { $0.lastPathComponent.lowercased().contains(keyword) }),
           let image = UIImage(contentsOfFile: named.path) {
            return image
        }

        return nil
    }
}

/// Covers the game for one second: the picture, and the piece's shout.
struct SacrificeOverlay: View {
    let piece: SacrificePiece

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()

            VStack(spacing: 20) {
                picture

                Text(piece.shout)
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .tracking(1.2)
                    .foregroundStyle(Theme.gold)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.6), radius: 12, y: 4)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, 20)
            .scaleEffect(appeared ? 1 : 0.82)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.66)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var picture: some View {
        if let image = SacrificeArtwork.image(names: piece.pictureNames, keyword: piece.pictureKeyword) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(0.65), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.55), radius: 24, y: 12)
        } else {
            // Until the picture is in the app, the piece itself stands in for it.
            ZStack {
                Circle().fill(Theme.gold.opacity(0.12))
                Circle().strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1)
                Text(piece.glyph)
                    .font(.system(size: 96))
                    .foregroundStyle(Theme.ivory)
            }
            .frame(width: 210, height: 210)
        }
    }
}
