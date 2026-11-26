//
//  RookSacrificeOverlay.swift
//  StockPlay
//
//  The easter egg: a rook given away for a cheaper piece gets the picture and the shout.
//

import SwiftUI
import UIKit

enum RookMeme {
    static let image: UIImage? = load()

    /// Finds the picture whether it is an asset, a bundled file, or just the one image added.
    private static func load() -> UIImage? {
        let extensions = ["png", "jpg", "jpeg", "heic"]

        for ext in extensions {
            if let url = Bundle.main.url(forResource: "TheRook", withExtension: ext),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }

        var candidates: [URL] = []
        for ext in extensions {
            candidates.append(contentsOf: Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [])
        }

        if let match = candidates.first(where: { $0.lastPathComponent.lowercased().contains("rook") }),
           let image = UIImage(contentsOfFile: match.path) {
            return image
        }

        // Otherwise the biggest loose picture in the app is the one that was added for this.
        let biggest = candidates
            .compactMap { url -> (URL, Int)? in
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let size = attributes[.size] as? NSNumber else {
                    return nil
                }
                return (url, size.intValue)
            }
            .filter { $0.1 > 60_000 }
            .sorted { $0.1 > $1.1 }
            .first

        if let biggest = biggest, let image = UIImage(contentsOfFile: biggest.0.path) {
            return image
        }

        return nil
    }
}

/// Covers the game for one second: the picture, and THE ROOOOOOOKKK.
struct RookSacrificeOverlay: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()

            VStack(spacing: 20) {
                picture

                Text("THE ROOOOOOOKKK")
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
        if let image = RookMeme.image {
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
            // Until the picture is in the app, the rook itself stands in for it.
            ZStack {
                Circle().fill(Theme.gold.opacity(0.12))
                Circle().strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1)
                Text(PieceKind.rook.glyph)
                    .font(.system(size: 96))
                    .foregroundStyle(Theme.ivory)
            }
            .frame(width: 210, height: 210)
        }
    }
}
