// © BCE Labs, 2024. All rights reserved.
//

import MusicKit

extension ApplicationMusicPlayer: MusicService {

    public var authorizationStatus: MusicAuthorizationStatus {
        .init(musicAuthorizationStatus: MusicAuthorization.currentStatus)
    }
    
    public var queueIsEmpty: Bool {
        queue.entries.isEmpty
    }
    
    public var playbackStatus: MusicPlaybackStatus {
        .init(applicationPlaybackStatus: ApplicationMusicPlayer.shared.state.playbackStatus)
    }
    
    public var currentSong: MusicXSong? {
        switch queue.currentEntry?.item {
        case .song(let song):
            return .init(song: song)
        default:
            return nil
        }
    }
    
    @discardableResult
    public func requestAuthorization() async -> MusicAuthorizationStatus {
        switch MusicAuthorization.currentStatus {
        case .notDetermined:
            let result = await MusicAuthorization.request()
            return .init(musicAuthorizationStatus: result)
        default:
            return .init(musicAuthorizationStatus: MusicAuthorization.currentStatus)
        }
    }
    
    public func enqueue(song: MusicXSong) async throws {
        if queueIsEmpty {
            queue = [song]
        } else {
            try await queue.insert(song, position: .tail)
        }
    }
}
