// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SwiftData

@Reducer
struct SettingsFeature {

    @ObservableState
    struct State: Equatable {
        var autoPlay: Bool = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.autoPlay.rawValue)
        var hiddenGenres: [String] = UserDefaults.standard.hiddenGenres

        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action {
        case onAppear
        case toggleAutoPlay(Bool)
        case unhideGenre(String)
        case clearHistoryButtonTapped
        case alert(PresentationAction<Alert>)

        enum Alert: Equatable {
            case clearHistoryConfirmed
        }
    }

    @Dependency(\.database) var database

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Genres are hidden from the Discover tab, so refresh the
                // list whenever this screen comes back into view.
                state.hiddenGenres = UserDefaults.standard.hiddenGenres
                return .none
            case .toggleAutoPlay(let autoPlay):
                state.autoPlay = autoPlay
                UserDefaults.standard.set(autoPlay, forKey: Constants.UserDefaultsKey.autoPlay.rawValue)
                return .none
            case .unhideGenre(let genre):
                state.hiddenGenres.removeAll { $0 == genre }
                UserDefaults.standard.hiddenGenres = state.hiddenGenres
                return .none
            case .clearHistoryButtonTapped:
                state.alert = AlertState {
                    TextState("Clear History?")
                } actions: {
                    ButtonState(role: .destructive, action: .clearHistoryConfirmed) {
                        TextState("Clear")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This removes every song from your history. Saved songs are kept.")
                }
                return .none
            case .alert(.presented(.clearHistoryConfirmed)):
                let context = database.context()
                let descriptor = FetchDescriptor<Media>(predicate: #Predicate { !$0.bookmarked })
                if let items = try? context.fetch(descriptor) {
                    for item in items {
                        context.delete(item)
                    }
                    try? context.save()
                }
                return .none
            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
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

            Section {
                if store.hiddenGenres.isEmpty {
                    Text("No hidden genres yet. Tap a genre tag in Discover to hide it.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.hiddenGenres, id: \.self) { genre in
                        Text(genre)
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.send(.unhideGenre(genre), animation: .snappy)
                                } label: {
                                    Label("Unhide", systemImage: "trash.fill")
                                }
                            }
                    }
                }
            } header: {
                Text("Hidden Genres")
            } footer: {
                if !store.hiddenGenres.isEmpty {
                    Text("Songs in these genres are skipped. Swipe left to unhide one.")
                }
            }

            Section {
                Button("Clear History", role: .destructive) {
                    store.send(.clearHistoryButtonTapped)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}

#Preview {
    SettingsView(store: .init(initialState: SettingsFeature.State(), reducer: {
        SettingsFeature()
    }))
}
