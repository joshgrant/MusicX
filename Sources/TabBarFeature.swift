//
// © BCE Labs, 2024. All rights reserved.
// 

import Foundation
import ComposableArchitecture

@Reducer
struct TabBarFeature {
    
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .listen
    }
    
    enum Action {
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            return .none
        }
    }
}

@Reducer
enum Tab {
    case listen
    case history
    case saved
    case settings
}

import SwiftUI

struct TabBarView: View {
    
    @Bindable var store: StoreOf<TabBarFeature>
    
    @State var selectedTab: Tab = .listen
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Text("Listen").tabItem { Text("Tab Label 1") }
                .tag(Tab.listen)
            Text("History").tabItem { Text("Tab Label 2") }
                .tag(Tab.history)
            Text("Saved").tabItem { Text("Tab Label 3") }
                .tag(Tab.saved)
            Text("Settings").tabItem { Text("Tab Label 4") }
                .tag(Tab.settings)
        }
    }
}

#Preview {
    TabBarView(store: .init(initialState: TabBarFeature.State(), reducer: {
        TabBarFeature()
    }))
}

