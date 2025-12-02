// © BCE Labs, 2024. All rights reserved.
//

import Testing
import MusicXCore

struct AppStateTests {
    
    let appState = AppState(
        settings: .init(
            searchType: .song,
            randomMode: .chaotic,
            autoPlay: true,
            includeTopResults: true),
        history: [],
        bookmarks: [],
        uiState: .init(isSearching: false)
    )
    
    @Test
    func skippingBackwardWhenNoHistoryDoesNothing() async throws {
        let musicServiceSpy = MusicServiceSpy()
        let container = try Container(
            logger: .init(.disabled),
            model: .init(source: .preTrainedBundleModel(.init(name: "song-titles", cohesion: 3, fileExtension: "media"))),
            musicService: musicServiceSpy,
            appState: appState)
        
        await container.musicService.requestAuthorization()
        #expect(musicServiceSpy.spyLog.first == "requestAuthorization()")
        
        try await skipBackward(container: container)
        #expect(musicServiceSpy.spyLog.last == "skipToPreviousEntry()")
    }
}
