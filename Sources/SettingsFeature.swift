// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var autoPlay: Bool = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.autoPlay.rawValue)
    }

    enum Action {
        case toggleAutoPlay(Bool)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .toggleAutoPlay(let autoPlay):
                state.autoPlay = autoPlay
                UserDefaults.standard.set(autoPlay, forKey: Constants.UserDefaultsKey.autoPlay.rawValue)
                return .none
            }
        }
    }
}

import SwiftUI

struct SettingsView: View {
    
    @Bindable var store: StoreOf<SettingsFeature>
    
    var body: some View {
#if os(macOS)
        form
            .padding(16)
#elseif os(iOS)
        NavigationStack {
            form
                .navigationTitle("Settings")
        }
#endif
    }
    
    var form: some View {
        Form {
            Toggle(isOn: $store.autoPlay.sending(\.toggleAutoPlay)) {
                Text("Auto Play")
            }
        }
    }
}

#Preview {
    SettingsView(store: .init(initialState: SettingsFeature.State(), reducer: {
        SettingsFeature()
    }))
}

