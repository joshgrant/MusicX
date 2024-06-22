// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture

@Reducer
struct HistoryFeature {
    
    @ObservableState
    struct State: Equatable {
        var showingOnlyBookmarks: Bool = false
        var songSnippets: IdentifiedArrayOf<SongSnippetFeature.State> = .init(uniqueElements: [])
    }
    
    enum Action {
        case onAppear
        case gotFetchResults([Media])
        case delete(Media)
    }
    
    @Dependency(\.database) var database
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let descriptor = FetchDescriptor<Media>(sortBy: [.init(\.timestamp)])
                    let results = try database.context().fetch(descriptor)
                    await send(.gotFetchResults(results))
                }
            case .gotFetchResults(let media):
                state.songSnippets = .init(uniqueElements: media.map {
                    .init(media: $0)
                })
                return .none
            case .delete:
                return .none
            }
        }
    }
}

import SwiftUI
import SwiftData

struct HistoryView: View {
    
    @Bindable var store: StoreOf<HistoryFeature>
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(snippets.reversed()) { state in
                        SongSnippetView(store: .init(initialState: state, reducer: {
                            SongSnippetFeature()
                        }))
                    }
                }
                .padding(16)
            }
            .navigationTitle("History")
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
    
    var snippets: IdentifiedArrayOf<SongSnippetFeature.State>  {
        if store.showingOnlyBookmarks {
            store
                .songSnippets
                .filter { $0.media.bookmarked }
        } else {
            store
                .songSnippets
        }
    }
}

#Preview {
    HistoryView(store: .init(initialState: HistoryFeature.State(), reducer: {
        HistoryFeature()
    }))
}

