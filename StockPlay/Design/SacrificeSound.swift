//
//  SacrificeSound.swift
//  StockPlay
//
//  The rook's noise, played whenever a rook-sacrifice picture appears.
//

import Foundation
import AVFoundation

enum SacrificeSound {
    /// Held so the sound is not cut off by its player going out of scope.
    private static var audioPlayer: AVAudioPlayer?
    private static var videoPlayer: AVPlayer?

    static func playRookSound() {
        // Plays even with the ring switch on silent, and lets any music keep playing.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let urls = rookSoundURLs()
        guard let first = urls.first else { return }

        for url in urls {
            if let audio = try? AVAudioPlayer(contentsOf: url), audio.prepareToPlay() {
                audio.play()
                audioPlayer = audio
                return
            }
        }

        // A file Core Audio will not open (a video container, say) still plays its sound here.
        let player = AVPlayer(url: first)
        player.play()
        videoPlayer = player
    }

    private static func rookSoundURLs() -> [URL] {
        var urls: [URL] = []
        let names = ["TheRookSound", "TheRook", "THE ROOK", "THEROOK"]
        let extensions = ["m4a", "mp3", "mp4", "wav", "aiff", "caf"]

        for name in names {
            for ext in extensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    urls.append(url)
                }
            }
        }

        for ext in extensions {
            let all = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
            urls.append(contentsOf: all.filter { $0.lastPathComponent.lowercased().contains("rook") })
        }

        var seen = Set<String>()
        return urls.filter { seen.insert($0.lastPathComponent).inserted }
    }
}
