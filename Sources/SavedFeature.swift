// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SwiftData

@Reducer
struct SavedFeature {
    
    @ObservableState
    struct State: Equatable {
        var savedItems: [Media] = []
    }
    
    enum Action {
        case queryChangedMedia([Media])
        case delete(Media)
    }
    
    @Dependency(\.database) var database
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            return .none
        }
    }
}

import SwiftUI

struct SavedView: View {
    
    @Bindable var store: StoreOf<SavedFeature>
    
    @Query var mediaQuery: [Media] {
        didSet {
            store.send(.queryChangedMedia(self.savedMedia))
        }
    }
    
    var body: some View {
        Text("Saved")
    }
}

#Preview {
    SavedView(store: .init(initialState: SavedFeature.State(), reducer: {
        SavedFeature()
    }))
}

