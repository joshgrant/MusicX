// © BCE Labs, 2024. All rights reserved.
//

import Testing
import OSLog
import MusicXCore
import SmallCharacterModel
import MusicKit

struct AppStateTests {
    
    // MARK: - Properties
    
    let logger: Logger
    let appState: AppState
    let model: CharacterModelState
    
    // MARK: - Initialization
    
    init() throws {
        logger = .init(.disabled)
        appState = AppState(
            settings: .init(
                randomMode: .chaotic,
                autoPlay: true,
                includeTopResults: true),
            history: [],
            bookmarks: [],
            uiState: .init(isSearching: false)
        )
        model = try CharacterModelState(source: .preTrainedBundleModel(.init(
            name: "song-titles",
            cohesion: 3,
            fileExtension: "media"
        )))
    }
    
    // MARK: - Tests
    
    @Test
    func skippingBackwardWhenNoHistoryDoesNothing() async throws {
        let musicServiceSpy = MusicServiceSpy()
        let container = try Container(
            logger: logger,
            model: model,
            musicService: musicServiceSpy,
            appState: appState)
        
        await container.musicService.requestAuthorization()
        #expect(musicServiceSpy.spyLog.first == "requestAuthorization()")
        
        try await skipBackward(container: container)
        #expect(musicServiceSpy.spyLog.last == "skipToPreviousEntry()")
    }
    
    @Test
    func playWithNoConfigurationStartsPlaying() async throws {
        let musicServiceSpy = MusicServiceSpy()
        let container = try Container(
            logger: logger,
            model: model,
            musicService: musicServiceSpy,
            appState: appState)
        
        await container.musicService.requestAuthorization()
        try await play(container: container)
        #expect(musicServiceSpy.spyLog.last == "")
    }
}
