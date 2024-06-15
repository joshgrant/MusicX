// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SmallCharacterModel

@Reducer
struct AppFeature {
    
    enum Tab {
        case listen
        case history
        case saved
        case settings
    }
    
    @ObservableState
    struct State: Equatable {
//        var sharedModelContainer: ModelContainer = {
//            let schema = Schema([
//                Item.self,
//            ])
//            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//
//            do {
//                return try ModelContainer(for: schema, configurations: [modelConfiguration])
//            } catch {
//                fatalError("Could not create ModelContainer: \(error)")
//            }
//        }()
        
        var selectedTab: Tab = .listen
        
        var listen = ListenFeature.State()
        var history = HistoryFeature.State()
        var saved = SavedFeature.State()
        var settings = SettingsFeature.State()
    }
    
    enum Action {
        case selectedTabChanged(Tab)
        
        case listen(ListenFeature.Action)
        case history(HistoryFeature.Action)
        case saved(SavedFeature.Action)
        case settings(SettingsFeature.Action)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .selectedTabChanged(let tab):
                state.selectedTab = tab
                return .none
            case .listen, .history, .saved, .settings:
                return .none
            }
        }
        
        Scope(state: \.listen, action: \.listen) {
            ListenFeature()
        }
        
        Scope(state: \.history, action: \.history) {
            HistoryFeature()
        }
        
        Scope(state: \.saved, action: \.saved) {
            SavedFeature()
        }
        
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
    }
}

import SwiftUI

struct AppView: View {
    
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.selectedTabChanged)) {
            ListenView(store: store.scope(state: \.listen, action: \.listen))
                .tabItem {
                    Image(systemName: "music.note")
                    Text("Listen")
                }
                .tag(AppFeature.Tab.listen)
            HistoryView(store: store.scope(state: \.history, action: \.history))
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
                .tag(AppFeature.Tab.history)
            SavedView(store: store.scope(state: \.saved, action: \.saved))
                .tabItem {
                    Image(systemName: "bookmark.fill")
                    Text("Saved")
                }
                .tag(AppFeature.Tab.saved)
            SettingsView(store: store.scope(state: \.settings, action: \.settings))
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(AppFeature.Tab.settings)
        }
    }
}

#Preview {
    AppView(store: .init(initialState: AppFeature.State(), reducer: {
        AppFeature()
    }))
}
