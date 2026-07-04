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
        var queuedSongID: MusicItemID?
    }

    enum Action {
        case onAppear
        case pause
        case resume
        case playSong(Song)
        case seek(TimeInterval)
    }

    // Back to dependency?
    var player: ApplicationMusicPlayer = .shared

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !player.isPreparedToPlay else { return .none }
                return .run { send in
                    do {
                        try await player.prepareToPlay()
                    } catch {
                        print("Failed to prepare the player: \(error)")
                    }
                }
            case .pause:
                state.isPlaying = false
                player.pause()
                return .none
            case .resume:
                state.isPlaying = true
                return .run { send in
                    do {
                        try await player.play()
                    } catch {
                        print(error)
                    }
                }
            case .playSong(let song):
                state.isPlaying = true
                state.queuedSongID = song.id
                return .run { send in
                    do {
                        player.queue = [song]
                        try await player.play()
                    } catch {
                        print(error)
                    }
                }
            case .seek(let time):
                player.playbackTime = time
                return .none
            }
        }
    }
}
