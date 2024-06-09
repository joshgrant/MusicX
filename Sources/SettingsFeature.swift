// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture

@Reducer
struct SettingsFeature {
    
    enum SearchType: LocalizedStringKey, CaseIterable, Hashable {
        case album = "Album"
        case song = "Song"
        case artist = "Artist"
    }
    
    enum RandomMode: LocalizedStringKey, CaseIterable, Hashable {
        case probable = "Probable"
        case chaotic = "Chaotic"
    }
    
    @ObservableState
    struct State: Equatable {
        var searchType: SearchType = .song
        var randomMode: RandomMode = .probable
        var autoPlay = true
    }
    
    enum Action {
        case searchTypeChanged(SearchType)
        case randomModeChanged(RandomMode)
        case toggleAutoPlay(Bool)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .searchTypeChanged(let searchType):
                state.searchType = searchType
                return .none
            case .randomModeChanged(let randomMode):
                state.randomMode = randomMode
                return .none
            case .toggleAutoPlay(let autoPlay):
                state.autoPlay = autoPlay
                return .none
            }
        }
    }
}

import SwiftUI

struct SettingsView: View {
    
    @Bindable var store: StoreOf<SettingsFeature>
    
    var body: some View {
        NavigationStack {
            List {
                HStack {
                    Picker("Search Type", selection: $store.searchType.sending(\.searchTypeChanged)) {
                        ForEach(SettingsFeature.SearchType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                                .tag(type)
                        }
                    }
                }
                
                HStack {
                    Picker("Random Mode", selection: $store.randomMode.sending(\.randomModeChanged)) {
                        ForEach(SettingsFeature.RandomMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue)
                                .tag(mode)
                        }
                    }
                }
                
                HStack {
                    Toggle(isOn: $store.autoPlay.sending(\.toggleAutoPlay)) {
                        Text("Auto Play")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(store: .init(initialState: SettingsFeature.State(), reducer: {
        SettingsFeature()
    }))
}

