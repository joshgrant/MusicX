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
        case play
        case pause
//        case playSong(Song)
//        case playMedia(MusicItemID)
        case enqueueSong(Song)
        case enqueueMedia(MusicItemID)
        case skip
    }
    
    // Back to dependency?
    var player = ApplicationMusicPlayer.shared
    
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
                return .run { send in
                    player.pause()
                }
//            case .playSong(let song):
//                state.isPlaying = true
//                return .run { send in
//                    do {
//                        player.queue = [song]
//                        try await player.play()
//                    } catch {
//                        print(error)
//                    }
//                }
//            case .playMedia(let id):
//                return .run { send in
//                    let request = MusicCatalogResourceRequest<Song>(
//                        matching: \.id,
//                        equalTo: id)
//                    if let song = try await request.response().items.first {
//                        await send(.playSong(song))
//                    } else {
//                        fatalError()
//                    }
//                }
            case .play:
                state.isPlaying = true
                return .run { send in
                    do {
                        try await player.play()
                    } catch {
                        print(error)
                    }
                }
            case .enqueueSong(let song):
                return .run { send in
                    try await player.queue.insert(song, position: .afterCurrentEntry)
                }
            case .enqueueMedia(let id):
                return .run { send in
                    let request = MusicCatalogResourceRequest<Song>(
                        matching: \.id,
                        equalTo: id)
                    if let song = try await request.response().items.first {
                        await send(.enqueueSong(song))
                    } else {
                        fatalError()
                    }
                }
            case .skip:
                return .run { send in
                    try await player.skipToNextEntry()
                }
            }
        }
    }
}
