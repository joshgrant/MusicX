// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import MediaPlayer
import MusicKit
import Combine

@Reducer
struct MediaPlayerFeature {
    
    @ObservableState
    struct State: Equatable {
        var isPlaying: Bool = false
        var autoPlay: Bool = false
    }
    
    enum Action {
        case onAppear
        case pause
        case playSong(Song)
        case playMedia(MusicItemID)
        case enqueue(Song)
        case skip
    }
    
    // Back to dependency?
    var player: ApplicationMusicPlayer = .shared
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                player.queue = []
                if !player.isPreparedToPlay {
                    return .run { send in
                        try await player.prepareToPlay()
                    }
                } else {
                    return .none
                }
            case .pause:
                state.isPlaying = false
                player.pause()
                return .none
            case .playSong(let song):
                state.isPlaying = true
                return .run { send in
                    do {
                        player.queue = [song]
                        try await player.play()
                    } catch {
                        print(error)
                    }
                }
            case .playMedia(let id):
                return .run { send in
                    let request = MusicCatalogResourceRequest<Song>(
                        matching: \.id,
                        equalTo: id)
                    if let song = try await request.response().items.first {
                        await send(.playSong(song))
                    } else {
                        fatalError()
                    }
                }
            case .enqueue(let song):
                return .run { send in
                    try await player.queue.insert(song, position: .afterCurrentEntry)
                }
            case .skip:
                return .run { send in
                    try await player.skipToNextEntry()
                }
            }
        }
    }
}
