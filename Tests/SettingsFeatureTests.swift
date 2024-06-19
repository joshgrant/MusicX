// © BCE Labs, 2024. All rights reserved.
//

import XCTest
import ComposableArchitecture

@testable import MusicX

final class SettingsFeatureTests: XCTestCase {

    @MainActor
    func test_changeSearchType() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        
        await store.send(.searchTypeChanged(.album)) {
            $0.searchType = .album
        }
        
        await store.send(.searchTypeChanged(.artist)) {
            $0.searchType = .artist
        }
        
        await store.send(.searchTypeChanged(.song)) {
            $0.searchType = .song
        }
    }
    
    @MainActor
    func test_changeRandomMode() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        
        await store.send(.randomModeChanged(.chaotic)) {
            $0.randomMode = .chaotic
        }
        
        await store.send(.randomModeChanged(.probable)) {
            $0.randomMode = .probable
        }
    }
    
    @MainActor
    func test_changeAutoPlay() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
        
        await store.send(.toggleAutoPlay(false)) {
            $0.autoPlay = false
        }
        
        await store.send(.toggleAutoPlay(true)) {
            $0.autoPlay = true
        }
    }
}
