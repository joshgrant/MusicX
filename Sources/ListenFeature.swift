// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture

@Reducer
struct ListenFeature {
    
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

struct ListenView: View {
    
    @Bindable var store: StoreOf<ListenFeature>
    
    var body: some View {
        Text("Listen")
    }
}

#Preview {
    ListenView(store: .init(initialState: ListenFeature.State(), reducer: {
        ListenFeature()
    }))
}

