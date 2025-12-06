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
    
    public var nextSong: MusicXSong? {
        // Entries does not have `[safe: #]` array access, unfortunately
        guard queue.entries.count > 1 else { return nil }
        switch queue.entries[1].item {
        case .song(let song):
            return .init(song: song)
        default:
            return nil
        }
    }
    
    @discardableResult
    public func requestAuthorization() async -> MusicAuthorizationStatus {
        let result = await MusicAuthorization.request()
        return .init(musicAuthorizationStatus: result)
    }
    
    public func findSongs(
        term: String,
        includeTopResults: Bool
    ) async throws -> [MusicXSong] {
        var request = MusicCatalogSearchRequest(
            term: term,
            types: [Song.self]
        )
        request.limit = 5
        request.includeTopResults = includeTopResults
        
        return try await request
            .response()
            .songs
            .map {
                .init(song: $0)
            }
    }
    
    public func enqueue(song: MusicXSong) async throws {
        queue = [song]
    }
}

extension ApplicationMusicPlayer: @retroactive CustomStringConvertible {
    public var description: String {
        """
        Authorization status: \(MusicAuthorization.currentStatus)
        Queue is empty: \(queueIsEmpty)
        Playback status: \(playbackStatus)
        Current song: \(currentSong?.title ?? "None")
        Next song: \(nextSong?.title ?? "None")
        """
    }
}

extension ApplicationMusicPlayer: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        description
    }
}
