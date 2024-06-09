// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture

@Reducer
struct HistoryFeature {
    
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

struct HistoryView: View {
    
    @Bindable var store: StoreOf<HistoryFeature>
    
    var body: some View {
        Text("History")
    }
}

#Preview {
    HistoryView(store: .init(initialState: HistoryFeature.State(), reducer: {
        HistoryFeature()
    }))
}

