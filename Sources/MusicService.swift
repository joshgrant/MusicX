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
    /// Searches the catalog, dropping songs whose genres appear in
    /// `hiddenGenres` (lowercased names) before they reach the caller.
    /// The Apple Music search API has no server-side genre parameter, so
    /// this is the earliest point the filter can run.
    var search: (_ searchTerm: String, _ hiddenGenres: Set<String>) async throws -> [Media]
    
    var playbackTime: () -> TimeInterval
    var playbackStatus: () -> MusicPlayer.PlaybackStatus
    var playbackRate: () -> Float
    var currentEntryID: () -> MusicItemID?
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
        search: { searchTerm, hiddenGenres in
            var request = MusicCatalogSearchRequest(
                term: searchTerm,
                types: [Song.self])
            request.limit = 5

            let response = try await request.response()

            return response.songs
                .filter { song in
                    !song.genreNames.contains { hiddenGenres.contains($0.lowercased()) }
                }
                .map { .init(song: $0) }
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
        currentEntryID: {
            ApplicationMusicPlayer.shared.queue.currentEntry?.item?.id
        }
    )
    
    static var testValue: MusicService = .init(
        authorizationStatus: { .authorized },
        search: { searchTerm, hiddenGenres in
            return [
            ]
        },
        playbackTime: { 1 },
        playbackStatus: { .playing },
        playbackRate: { 1 },
        currentEntryID: { nil }
    )
}

extension DependencyValues {
    
    var musicService: MusicService {
        get { self[MusicService.self] }
        set { self[MusicService.self] = newValue }
    }
    
}
