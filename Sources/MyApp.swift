// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import SwiftData

@main
struct MyApp: App {
    
    static var store = StoreOf<AppFeature>(initialState: AppFeature.State()) {
        AppFeature()
//            ._printChanges()
    }
    
    var body: some Scene {
        WindowGroup {
            if !_XCTIsTesting {
                AppView(store: MyApp.store)
            } else {
                EmptyView()
            }
        }
    }
}
