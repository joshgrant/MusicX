// © BCE Labs, 2024. All rights reserved.
//

import XCTest
import ComposableArchitecture

@testable import MusicX

final class SettingsFeatureTests: XCTestCase {

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
