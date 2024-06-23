// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import SwiftData

@main
struct MyApp: App {
    
//    static let sharedContext: ModelContext = {
//        do {
//            let schema = Schema([Media.self])
//            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//            let container = try ModelContainer(for: schema, configurations: [configuration])
//            return ModelContext(container)
//        } catch {
//            fatalError("Failed to create container.")
//        }
//    }()
    
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
//        .modelContext(MyApp.sharedContext)
    }
}
