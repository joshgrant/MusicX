//
// © BCE Labs, 2024. All rights reserved.
// 

import Foundation
import ComposableArchitecture

@Reducer
struct TabBarFeature {
    
    @ObservableState
    struct State: Equatable {
        
    }
    
    enum Action {
        
    }
    
    var body: some ReducerOf<Self> {
        Reducer { state, action in
            switch action {
                
            }
        }
    }
}

import SwiftUI

struct TabBarView: View {
    
    @Bindable var store: StoreOf<TabBarFeature>
    
    var body: some View {
        
    }
}

#Preview {
    TabBarView(store: .init(initialState: TabBarFeature.State(), reducer: {
        TabBarFeature()
    }))
}

