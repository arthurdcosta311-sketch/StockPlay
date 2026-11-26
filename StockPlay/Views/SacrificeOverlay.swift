//
//  SacrificeOverlay.swift
//  StockPlay
//
//  The easter egg: a rook or a bishop given away for a cheaper piece gets its
//  picture and its shout.
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
}

enum SacrificeMemes {
    private static var cache: [String: UIImage] = [:]
    private static var tried = Set<String>()

    static func image(for piece: SacrificePiece) -> UIImage? {
        if let cached = cache[piece.rawValue] { return cached }
        if tried.contains(piece.rawValue) { return nil }

        let image = load(for: piece)
        tried.insert(piece.rawValue)
        if let image = image {
            cache[piece.rawValue] = image
        }
        return image
    }

    private static func load(for piece: SacrificePiece) -> UIImage? {
        // An asset catalog entry with the right name, whichever spelling it uses.
        for name in piece.pictureNames {
            if let image = UIImage(named: name) {
                return image
            }
        }

        let extensions = ["png", "jpg", "jpeg", "webp", "heic"]

        // A file added to the app's folder, again by name.
        for name in piece.pictureNames {
            for ext in extensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext),
                   let image = UIImage(contentsOfFile: url.path) {
                    return image
                }
            }
        }

        var loose: [URL] = []
        for ext in extensions {
            loose.append(contentsOf: Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [])
        }

        // Any picture whose file name mentions the piece.
        if let named = loose.first(where: { $0.lastPathComponent.lowercased().contains(piece.pictureKeyword) }),
           let image = UIImage(contentsOfFile: named.path) {
            return image
        }

        // A single loose picture in the app can only be the one added for this.
        let pictures = loose.compactMap { url -> (URL, Int)? in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attributes[.size] as? NSNumber,
                  size.intValue > 60_000 else {
                return nil
            }
            return (url, size.intValue)
        }

        if pictures.count == 1, let only = pictures.first, let image = UIImage(contentsOfFile: only.0.path) {
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
        if let image = SacrificeMemes.image(for: piece) {
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
