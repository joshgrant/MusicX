// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture

@Reducer
struct SettingsFeature {
    
    @ObservableState
    struct State: Equatable {
        
    }
    
    enum Action {
        
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            return .none
        }
    }
}

import SwiftUI

struct SettingsView: View {
    
    @Bindable var store: StoreOf<SettingsFeature>
    
    var body: some View {
        Text("Settings")
    }
}

#Preview {
    SettingsView(store: .init(initialState: SettingsFeature.State(), reducer: {
        SettingsFeature()
    }))
}

