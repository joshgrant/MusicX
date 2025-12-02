// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SwiftUI
import SwiftData
import MusicKit
import MusicXCore

@main
struct MyApp: App {
    
    static let sharedContext: ModelContext = {
        do {
            let schema = Schema([Media.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return ModelContext(container)
        } catch {
            fatalError("Failed to create container.")
        }
    }()
    
//    static var store = StoreOf<AppFeature>(initialState: AppFeature.State()) {
//        AppFeature()
////            ._printChanges()
//    }
    
    let player = ApplicationMusicPlayer.shared
    
//    var appState = AppState(model: .init(source: .preTrainedBundleModel(.init(
//        name: "song-titles",
//        cohesion: 3,
//        fileExtension: "media"
//    ))))
    
    var body: some Scene {
        WindowGroup {
//            AppView(store: MyApp.store)
            Text("Hi")
                .onAppear {
                    Task {
//                        try await globalFunction()
//                        do {
//                            try await AppState.configure(player: player, appState: appState)
//                            if let song = try await AppState.findSong(appState: appState, temporarySong: nil, query: nil) {
//                                try await AppState.play(song: song, musicPlayer: player, appState: appState)
//                            }
//                        } catch {
//                            print("Failed: \(error)")
//                        }
                    }

                }
        }
        .modelContext(MyApp.sharedContext)
    }
}
