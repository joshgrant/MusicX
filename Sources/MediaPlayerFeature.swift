// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import MediaPlayer
import MusicKit

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
        case play(MediaInformation)
        case enqueue(Song)
        case skip
    }
    
    @Dependency(\.musicPlayer) var musicPlayer
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                musicPlayer.queue = []
                if !musicPlayer.isPreparedToPlay {
                    return .run { send in
                        try await musicPlayer.prepareToPlay()
                    }
                } else {
                    return .none
                }
            case .pause:
                state.isPlaying = false
                musicPlayer.pause()
                return .none
            case .play(let mediaInformation):
                guard let song = mediaInformation.song else {
                    state.isPlaying = false
                    return .none
                }
                state.isPlaying = true
                return .run { send in
                    do {
                        musicPlayer.queue = [song]
                        try await musicPlayer.play()
                    } catch {
                        print(error)
                    }
                }
            case .enqueue(let song):
                return .run { send in
                    try await musicPlayer.queue.insert(song, position: .afterCurrentEntry)
                }
            case .skip:
                return .run { send in
                    try await musicPlayer.skipToNextEntry()
                }
            }
        }
    }
}
