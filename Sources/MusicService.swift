// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import MusicKit
import Combine

struct MusicService {
    
    enum AuthorizationStatus {
        case authorized
        case unauthorized
        case restricted
        case notDetermined
    }
    
    var authorizationStatus: () -> AuthorizationStatus
    var search: (_ searchTerm: String) async throws -> [Media]
    
    var playbackTime: () -> TimeInterval
    var playbackStatus: () -> MusicPlayer.PlaybackStatus
    var playbackRate: () -> Float
    
    var currentSong: () -> Song?
}

extension MusicService: DependencyKey {
    
    static var liveValue: MusicService = .init(
        authorizationStatus: {
            switch MusicAuthorization.currentStatus {
            case .authorized:
                return .authorized
            case .denied:
                return .unauthorized
            case .restricted:
                return .restricted
            case .notDetermined:
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        },
        search: { searchTerm in
            var request = MusicCatalogSearchRequest(
                term: searchTerm,
                types: [Song.self])
            request.limit = 5
            
            let response = try await request.response()
            
            return response.songs.map { .init(song: $0) }
        },
        playbackTime: {
            ApplicationMusicPlayer.shared.playbackTime
        },
        playbackStatus: {
            ApplicationMusicPlayer.shared.state.playbackStatus
        },
        playbackRate: {
            ApplicationMusicPlayer.shared.state.playbackRate
        },
        currentSong: {
            switch ApplicationMusicPlayer.shared.queue.currentEntry?.item {
            case .song(let song):
                return song
            default:
                return nil
            }
        }
    )
    
    static var testValue: MusicService = .init(
        authorizationStatus: { .authorized },
        search: { searchTerm in
            return [
            ]
        },
        playbackTime: { 1 },
        playbackStatus: { .playing },
        playbackRate: { 1 },
        currentSong: { nil }
    )
}

extension DependencyValues {
    
    var musicService: MusicService {
        get { self[MusicService.self] }
        set { self[MusicService.self] = newValue }
    }
    
}
