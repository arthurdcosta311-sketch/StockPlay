//
//  StockfishSession.swift
//  StockPlay
//
//  A synchronous wrapper around the embedded Stockfish engine: one handshake,
//  then one blocking search at a time, serialised by an actor.
//

import Foundation
import SFEngine

/// Carries the engine's line handler until `StockfishSession` can install its own.
private final class LineBox: @unchecked Sendable {
    var handler: ((String) -> Void)?
}

struct StockfishAssessment: Sendable {
    var move: String?
    /// Centipawns from the side to move, with a mate folded into a large score.
    var score: Int
    /// Mate in this many moves, positive when the side to move mates.
    var mate: Int?
}

/// Owns one `SFEngine`. Not thread safe: `StockfishRunner` serialises it.
final class StockfishSession: @unchecked Sendable {
    private let engine: SFEngine
    private let lock = NSLock()

    private var readySemaphore: DispatchSemaphore?
    private var isReady = false
    private var moveSemaphore: DispatchSemaphore?
    private var pendingMove: String?
    private var latestScore = 0
    private var latestMate: Int?
    private var latestPVMove: String?

    init(networkURL: URL) {
        let box = LineBox()
        self.engine = SFEngine(networkFileURL: networkURL) { line in
            box.handler?(line)
        }
        box.handler = { [weak self] line in
            self?.handle(line)
        }
    }

    /// Starts the engine and completes the UCI handshake. Blocking: call off the main actor.
    func handshake(timeout: TimeInterval = 25) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)

        lock.lock()
        readySemaphore = semaphore
        isReady = false
        lock.unlock()

        engine.start()
        engine.sendCommand("uci")
        engine.sendCommand("setoption name Threads value 1")
        engine.sendCommand("setoption name Hash value 64")

        let waited = semaphore.wait(timeout: .now() + timeout)

        lock.lock()
        let ready = isReady
        readySemaphore = nil
        lock.unlock()

        return waited == .success && ready
    }

    /// One search: the engine's move and the score it expects, from the side to move.
    func assess(fen: String, milliseconds: Int, timeout: TimeInterval = 8) -> StockfishAssessment? {
        let semaphore = DispatchSemaphore(value: 0)

        lock.lock()
        pendingMove = nil
        latestScore = 0
        latestMate = nil
        latestPVMove = nil
        moveSemaphore = semaphore
        lock.unlock()

        engine.sendCommand("position fen \(fen)")
        engine.sendCommand("go movetime \(milliseconds)")

        let waited = semaphore.wait(timeout: .now() + timeout)

        lock.lock()
        let move = pendingMove ?? latestPVMove
        let score = latestScore
        let mate = latestMate
        pendingMove = nil
        moveSemaphore = nil
        lock.unlock()

        guard waited == .success else {
            engine.sendCommand("stop")
            return nil
        }
        guard let best = move, best != "0000", best != "(none)" else { return nil }
        return StockfishAssessment(move: best, score: score, mate: mate)
    }

    func bestMove(fen: String, milliseconds: Int, timeout: TimeInterval = 8) -> String? {
        return assess(fen: fen, milliseconds: milliseconds, timeout: timeout)?.move
    }

    /// Terminal: the instance cannot be reused after this.
    func shutdown() {
        engine.stop()
    }

    private func handle(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed == "uciok" {
            engine.sendCommand("isready")
            return
        }
        if trimmed == "readyok" {
            lock.lock()
            isReady = true
            let semaphore = readySemaphore
            lock.unlock()
            semaphore?.signal()
            return
        }
        if trimmed.hasPrefix("bestmove") {
            let parts = trimmed.split(separator: " ")
            let move = parts.count > 1 ? String(parts[1]) : ""
            lock.lock()
            pendingMove = move
            let semaphore = moveSemaphore
            lock.unlock()
            semaphore?.signal()
            return
        }
        if trimmed.hasPrefix("info string") && trimmed.lowercased().contains("error") {
            lock.lock()
            let semaphore = moveSemaphore
            pendingMove = nil
            lock.unlock()
            semaphore?.signal()
            return
        }
        if trimmed.hasPrefix("info") {
            parseInfo(trimmed)
        }
    }

    /// Picks the score and the first move of the principal variation out of one info line.
    private func parseInfo(_ line: String) {
        let tokens = line.split(separator: " ").map(String.init)
        var index = 0

        while index < tokens.count {
            let token = tokens[index]

            if token == "score", index + 2 < tokens.count, let value = Int(tokens[index + 2]) {
                let kind = tokens[index + 1]
                lock.lock()
                if kind == "cp" {
                    latestScore = value
                    latestMate = nil
                } else if kind == "mate" {
                    latestMate = value
                    latestScore = value > 0
                        ? ReviewMath.mateCentipawns - value * 10
                        : -ReviewMath.mateCentipawns - value * 10
                }
                lock.unlock()
                index += 3
                continue
            }

            if token == "pv", index + 1 < tokens.count {
                lock.lock()
                latestPVMove = tokens[index + 1]
                lock.unlock()
                return
            }

            index += 1
        }
    }
}

/// Serialises every call into the engine: one search at a time, off the main actor.
actor StockfishRunner {
    private let session: StockfishSession

    init(session: StockfishSession) {
        self.session = session
    }

    func bestMove(fen: String, milliseconds: Int) -> String? {
        return session.bestMove(fen: fen, milliseconds: milliseconds)
    }

    func assess(fen: String, milliseconds: Int) -> StockfishAssessment? {
        return session.assess(fen: fen, milliseconds: milliseconds)
    }
}
