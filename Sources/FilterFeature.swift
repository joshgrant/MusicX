// © BCE Labs, 2024. All rights reserved.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct FilterFeature {
    
    @ObservableState
    struct State: Equatable {
        var showBookmarked: Bool = false
    }
    
    enum Action {
        case showBookmarked(Bool)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .showBookmarked(let show):
                state.showBookmarked = show
                return .none
            }
        }
    }
}

struct FilterView: View {
    
    @Bindable var store: StoreOf<FilterFeature>
    
    var body: some View {
#if os(macOS)
        form
            .padding(16)
#elseif os(iOS)
        form
#endif
    }
    
    var form: some View {
        Form {
            Toggle(isOn: $store.showBookmarked.sending(\.showBookmarked)) {
                Text("Show Saved")
            }
        }
    }
}

#Preview {
    FilterView(store: .init(initialState: FilterFeature.State(), reducer: {
        FilterFeature()
    }))
}
