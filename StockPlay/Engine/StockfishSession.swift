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

/// Owns one `SFEngine`. Not thread safe: `StockfishRunner` serialises it.
final class StockfishSession: @unchecked Sendable {
    private let engine: SFEngine
    private let lock = NSLock()

    private var readySemaphore: DispatchSemaphore?
    private var isReady = false
    private var moveSemaphore: DispatchSemaphore?
    private var pendingMove: String?

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

    /// One search. Returns the engine's move in long algebraic notation, or nil.
    func bestMove(fen: String, milliseconds: Int, timeout: TimeInterval = 8) -> String? {
        let semaphore = DispatchSemaphore(value: 0)

        lock.lock()
        pendingMove = nil
        moveSemaphore = semaphore
        lock.unlock()

        engine.sendCommand("position fen \(fen)")
        engine.sendCommand("go movetime \(milliseconds)")

        let waited = semaphore.wait(timeout: .now() + timeout)

        lock.lock()
        let move = pendingMove
        pendingMove = nil
        moveSemaphore = nil
        lock.unlock()

        guard waited == .success, let move = move, move != "0000", move != "(none)" else {
            if waited != .success {
                engine.sendCommand("stop")
            }
            return nil
        }
        return move
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
}
