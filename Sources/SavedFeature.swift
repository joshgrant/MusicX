// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture

@Reducer
struct SavedFeature {
    
    @ObservableState
    struct State: Equatable {
        var savedItems: [MediaInformation] = []
    }
    
    enum Action {
        case delete(MediaInformation)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            return .none
        }
    }
}

import SwiftUI

struct SavedView: View {
    
    @Bindable var store: StoreOf<SavedFeature>
    
    var body: some View {
        Text("Saved")
    }
}

#Preview {
    SavedView(store: .init(initialState: SavedFeature.State(), reducer: {
        SavedFeature()
    }))
}

