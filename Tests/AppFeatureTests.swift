// © BCE Labs, 2024. All rights reserved.
//

import XCTest
import ComposableArchitecture

@testable import MusicX

final class AppFeatureTests: XCTestCase {

    @MainActor
    func test_selectHistoryTab() async {
        let store = TestStore(initialState: AppFeature.State(), reducer: {
            AppFeature()
        })
        
        await store.send(.selectedTabChanged(.history)) {
            $0.selectedTab = .history
        }
        
        await store.send(.selectedTabChanged(.settings)) {
            $0.selectedTab = .settings
        }
        
        await store.send(.selectedTabChanged(.saved)) {
            $0.selectedTab = .saved
        }
        
        await store.send(.selectedTabChanged(.listen)) {
            $0.selectedTab = .listen
        }
    }
}
