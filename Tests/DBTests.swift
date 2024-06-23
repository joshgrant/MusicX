// © BCE Labs, 2024. All rights reserved.
//

import XCTest
import ComposableArchitecture
import MusicX

final class DBTests: XCTestCase {

    @MainActor
    func test_addGenres() async {
        let store = TestStore(initialState: GenresFeature.State()) {
            GenresFeature()
        }
        
        await store.send(.createTable) {
            $0.table = IdentifiedTable("genres")
        }
        await store.send(.addGenre("Rock"))
        await store.send(.addGenre("Hip-Hop"))
        await store.send(.addGenre("Classical"))
        
        await store.send(.fetchGenres)
        await store.receive(\.delegate.allGenresResult, ["Rock", "Hip-Hop", "Classical"])
    }
    
    @MainActor
    func test_addMedia() async {
        let store = TestStore(initialState: MediaFeature.State()) {
            MediaFeature()
        }
        
        await store.send(.createTable) {
            $0.table = IdentifiedTable("media")
        }
    }
    
    @MainActor
    func test_addMediaGenres() async {
        // TODO: This should allow us to link a media item with a genres table
    }
}
