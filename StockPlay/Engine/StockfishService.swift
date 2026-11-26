//
//  StockfishService.swift
//  StockPlay
//
//  Finds or downloads the Stockfish network once, then keeps the engine ready.
//  If any step fails the app keeps playing with the built-in engine.
//

import Foundation
import Observation

@MainActor
@Observable
final class StockfishService {
    enum State: Equatable {
        case idle
        case downloading
        case starting
        case ready
        case unavailable
    }

    static let shared = StockfishService()

    /// The network the embedded engine build needs, and where it comes from.
    private static let networkFileName = "nn-c9e480e92425.nnue"
    private static let networkURL = URL(string: "https://data.stockfishchess.org/nn/nn-c9e480e92425.nnue")!

    private(set) var state: State = .idle
    private(set) var networkSizeText = ""

    private var runner: StockfishRunner?
    private var prepareTask: Task<Void, Never>?
    private var failures = 0

    var isReady: Bool {
        return state == .ready
    }

    var statusText: String {
        switch state {
        case .idle, .starting:
            return "Starting Stockfish…"
        case .downloading:
            return "Downloading the Stockfish network — once, about 113 MB"
        case .ready:
            return "Stockfish engine ready"
        case .unavailable:
            return "Built-in engine in use — Stockfish network unavailable"
        }
    }

    /// Prepares the engine in the background. Safe to call repeatedly.
    func prepare() {
        guard prepareTask == nil, runner == nil else { return }
        prepareTask = Task { [weak self] in
            guard let self = self else { return }
            defer { self.prepareTask = nil }

            self.state = .downloading
            guard let networkURL = await self.networkFileURL() else {
                self.state = .unavailable
                return
            }

            self.state = .starting
            let session = await Task.detached(priority: .userInitiated) { () -> StockfishSession? in
                let session = StockfishSession(networkURL: networkURL)
                guard session.handshake() else {
                    session.shutdown()
                    return nil
                }
                return session
            }.value

            guard let session = session else {
                self.state = .unavailable
                return
            }

            self.runner = StockfishRunner(session: session)
            self.state = .ready
        }
    }

    /// One engine move in long algebraic notation, or nil to fall back.
    func uciMove(fen: String, milliseconds: Int) async -> String? {
        guard let runner = runner else { return nil }
        if let move = await runner.bestMove(fen: fen, milliseconds: milliseconds) {
            failures = 0
            return move
        }

        failures += 1
        if failures >= 2 {
            self.runner = nil
            state = .unavailable
        }
        return nil
    }

    // MARK: - Network file

    private func networkFileURL() async -> URL? {
        let fileManager = FileManager.default
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = support.appendingPathComponent("Stockfish", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(Self.networkFileName)

        if fileManager.fileExists(atPath: destination.path) {
            return destination
        }

        do {
            let (temporary, response) = try await URLSession.shared.download(from: Self.networkURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let size = (try? fileManager.attributesOfItem(atPath: temporary.path)[.size] as? NSNumber)??.intValue ?? 0
            guard size > 50_000_000 else { return nil }

            networkSizeText = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: temporary, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}
