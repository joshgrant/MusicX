// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import SwiftData

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
    
    static let configurationId: UUID? = {
        if UserDefaults.standard.value(forKey: Constants.UserDefaultsKey.configurationId.rawValue) == nil {
            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKey.autoPlay.rawValue)
            UserDefaults.standard.set(UUID().uuidString, forKey: Constants.UserDefaultsKey.configurationId.rawValue)
        }
        
        return UserDefaults.standard.value(forKey: Constants.UserDefaultsKey.configurationId.rawValue) as? UUID
    }()
    
    static var store = StoreOf<AppFeature>(initialState: AppFeature.State()) {
        AppFeature()
        //            ._printChanges()
    }
    
    var body: some Scene {
        WindowGroup {
            AppView(store: MyApp.store)
        }
        .modelContext(MyApp.sharedContext)
    }
}
