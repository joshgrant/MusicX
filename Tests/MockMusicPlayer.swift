// © BCE Labs, 2024. All rights reserved.
//

import MusicKit
import MusicXCore

class MusicServiceSpy: MusicService {
    var authorizationStatus: MusicAuthorizationStatus
    var queueIsEmpty: Bool
    var playbackStatus: MusicPlaybackStatus
    var currentSong: MusicXSong?
    var nextSong: MusicXSong?
    
    var spyLog: [String]
    
    init() {
        self.authorizationStatus = .notDetermined
        self.queueIsEmpty = true
        self.playbackStatus = .stopped
        self.currentSong = nil
        self.spyLog = []
    }
    
    func requestAuthorization() async -> MusicAuthorizationStatus {
        spyLog.append(#function)
        return .authorized
    }
    
    func findSongs(term: String, includeTopResults: Bool) async throws -> [MusicXCore.MusicXSong] {
        return [
            .init(id: .init(""), title: "Mock Song", artistName: "Mocky", genreNames: ["Mock"])
        ]
    }
    
    func prepareToPlay() async throws {
        spyLog.append(#function)
    }
    
    func enqueue(song: MusicXCore.MusicXSong) async throws {
        spyLog.append(#function)
    }
    
    func play() async throws {
        spyLog.append(#function)
        playbackStatus = .playing
    }
    
    func pause() {
        spyLog.append(#function)
    }
    
    func stop() {
        spyLog.append(#function)
    }
    
    func skipToNextEntry() async throws {
        spyLog.append(#function)
    }
    
    func skipToPreviousEntry() async throws {
        spyLog.append(#function)
    }
}
