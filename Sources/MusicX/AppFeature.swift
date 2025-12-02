//// © BCE Labs, 2024. All rights reserved.
////
//
//import Foundation
//import ComposableArchitecture
//import SmallCharacterModel
//import MusicKit
//
//@Reducer
//struct AppFeature {
//    
//    enum Tab {
//        case listen
//        case history
//        case saved
//        case settings
//    }
//    
//    enum FilterPickerOption: String {
//        case history = "History"
//        case saved = "Saved"
//    }
//    
//    @ObservableState
//    struct State: Equatable {
//        var selectedTab: Tab = .listen
//        var selectedFilterPickerOption: FilterPickerOption = .history
//        
//        var showingSettingsPopover: Bool = false
//        var showingOnlyBookmarkedItems: Bool = false
//        
//        var listen = ListenFeature.State()
//        var history = HistoryFeature.State()
//        var saved = SavedFeature.State()
//        var settings = SettingsFeature.State()
//    }
//    
//    enum Action {
//        case onAppear
//        
//        case selectedTabChanged(Tab)
//        case filterPickerOptionChanged(FilterPickerOption)
//        
//        case settingsButtonTapped(Bool)
//        
//        case listen(ListenFeature.Action)
//        case history(HistoryFeature.Action)
//        case saved(SavedFeature.Action)
//        case settings(SettingsFeature.Action)
//    }
//    
//    @Dependency(\.database) var database
//    
//    var body: some ReducerOf<Self> {
//        Reduce { state, action in
//            switch action {
//            case .onAppear:
//                return .merge([
//                    .run { send in
////                        do {
////                            try SCMFunctions.load(state: &appState.model)
////                        } catch {
////                            await send(.listen(.modelLoadingFailed(error)))
////                        }
//                    },
//                    .run { send in
//                        let result = await MusicAuthorization.request()
//                        await send(.listen(.authorized(result)))
//                    }
//                ])
//            case .selectedTabChanged(let tab):
//                state.selectedTab = tab
//                return .none
//            case .settingsButtonTapped(let show):
//                state.showingSettingsPopover = show
//                return .none
//            case .listen, .history, .saved, .settings:
//                return .none
//            case .filterPickerOptionChanged(let option):
//                state.selectedFilterPickerOption = option
//                
//                switch option {
//                case .history:
//                    state.showingOnlyBookmarkedItems = false
//                    state.history.showingOnlyBookmarks = false
//                case .saved:
//                    state.showingOnlyBookmarkedItems = true
//                    state.history.showingOnlyBookmarks = true
//                }
//                
//                return .none
//            }
//        }
//        
//        Scope(state: \.listen, action: \.listen) {
//            ListenFeature()
//        }
//        
//        Scope(state: \.history, action: \.history) {
//            HistoryFeature()
//        }
//        
//        Scope(state: \.saved, action: \.saved) {
//            SavedFeature()
//        }
//        
//        Scope(state: \.settings, action: \.settings) {
//            SettingsFeature()
//        }
//    }
//}
//
//import SwiftUI
//
//struct AppView: View {
//    
//    @Bindable var store: StoreOf<AppFeature>
//    
//    var body: some View {
//#if os(macOS)
//        HSplitView {
//            ListenView(store: store.scope(state: \.listen, action: \.listen))
//                .tabItem {
//                    Image(systemName: "music.note")
//                    Text("Listen")
//                }
//                .toolbar {
//                    Button {
//                        store.send(.settingsButtonTapped(true))
//                    } label: {
//                        Image(systemName: "gearshape")
//                    }.popover(isPresented: $store.showingSettingsPopover.sending(\.settingsButtonTapped)) {
//                        SettingsView(store: store.scope(state: \.settings, action: \.settings))
//                            .tabItem {
//                                Image(systemName: "gearshape.fill")
//                                Text("Settings")
//                            }
//                            .tag(AppFeature.Tab.settings)
//                    }
//                }
//            
//            HistoryView(store: store.scope(state: \.history, action: \.history))
//                .tabItem {
//                    Image(systemName: "clock.fill")
//                    Text("History")
//                }
//                .toolbar {
//                    ToolbarItem {
//                        Picker(selection: $store.selectedFilterPickerOption.sending(\.filterPickerOptionChanged)) {
//                            Text("History")
//                                .tag(AppFeature.FilterPickerOption.history)
//                            Text("Saved")
//                                .tag(AppFeature.FilterPickerOption.saved)
//                        } label: {
//                            Text(store.selectedFilterPickerOption.rawValue)
//                                .font(.headline)
//                        }
//                    }
//                }
//                .frame(minWidth: 300)
//        }
//        .onAppear {
//            store.send(.onAppear)
//        }
//#elseif os(iOS)
//        TabView(selection: $store.selectedTab.sending(\.selectedTabChanged)) {
//            ListenView(store: store.scope(state: \.listen, action: \.listen))
//                .tabItem {
//                    Image(systemName: "music.note")
//                    Text("Listen")
//                }
//                .tag(AppFeature.Tab.listen)
//            HistoryView(store: store.scope(state: \.history, action: \.history))
//                .tabItem {
//                    Image(systemName: "clock.fill")
//                    Text("History")
//                }
//                .tag(AppFeature.Tab.history)
//            SavedView(store: store.scope(state: \.saved, action: \.saved))
//                .tabItem {
//                    Image(systemName: "bookmark.fill")
//                    Text("Saved")
//                }
//                .tag(AppFeature.Tab.saved)
//            SettingsView(store: store.scope(state: \.settings, action: \.settings))
//                .tabItem {
//                    Image(systemName: "gearshape.fill")
//                    Text("Settings")
//                }
//                .tag(AppFeature.Tab.settings)
//        }
//        .onAppear {
//            store.send(.onAppear)
//        }
//#endif
//    }
//}
//
//#Preview {
//    AppView(store: .init(initialState: AppFeature.State(), reducer: {
//        AppFeature()
//    }))
//}
