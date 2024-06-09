// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

@main
struct MyApp: App {
    
    static var store = StoreOf<AppFeature>(initialState: AppFeature.State()) {
        AppFeature()
    }
    
    var body: some Scene {
        WindowGroup {
            AppView(store: MyApp.store)
        }
    }
}
