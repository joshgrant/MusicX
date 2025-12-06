// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SwiftUI
import MusicKit
import MusicXCore
import SmallCharacterModel

@main
struct MusicXApp: App {w
    
    @State var container = try! Container(
        logger: .init(subsystem: "MusicX", category: "General"),
        model: .init(source: .preTrainedBundleModel(.init(
            name: "song-titles",
            cohesion: 3,
            fileExtension: "media"))),
        musicService: ApplicationMusicPlayer.shared,
        appState: .init(
            settings: .init(
                randomMode: .probable,
                autoPlay: true,
                includeTopResults: false),
            history: [],
            bookmarks: [],
            uiState: .init(isSearching: false)
        )
    )
    
    var body: some Scene {
        WindowGroup {
            VStack {
                Text(container.musicService.currentSong?.title ?? "None")
                
                Text("Playback status: \(container.musicService.playbackStatus)")
                
                Button {
                    Task {
                        try! await play(container: container)
                    }
                } label: {
                    if container.appState.uiState.isSearching {
                        HStack {
                            ProgressView()
                            Text("Loading…")
                        }
                    } else {
                        Text("Play")
                    }
                }
                
                Button {
                    pause(container: container)
                } label: {
                    Text("Pause")
                }
                
                Button {
                    Task {
                        try await skipForward(container: container)
                    }
                } label: {
                    Text("Skip forward")
                }
                
                Button {
                    Task {
                        try await skipBackward(container: container)
                    }
                } label: {
                    Text("Skip backward")
                }
            }
            .task {
                await container.musicService.requestAuthorization()
            }
        }
    }
}
