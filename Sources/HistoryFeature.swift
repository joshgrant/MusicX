// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture

@Reducer
struct HistoryFeature {
    
    @ObservableState
    struct State: Equatable {
        var songSnippets: IdentifiedArrayOf<SongSnippetFeature.State> = .init(uniqueElements: [])
    }
    
    enum Action {
        case onAppear
        case gotFetchResults([Media])
        case delete(Media)
        case queryChangedMedia([Media])
    }
    
    @Dependency(\.database) var database
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let descriptor = FetchDescriptor<Media>()
                    let results = try database.context().fetch(descriptor)
                    await send(.gotFetchResults(results))
                }
            case .gotFetchResults(let media):
                state.songSnippets = .init(uniqueElements: media.map {
                    .init(media: $0)
                })
                return .none
            case .delete(let media):
                return .none
            case .queryChangedMedia(let media):
                state.songSnippets = .init(uniqueElements: (media.map({
                    .init(media: $0)
                })))
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
                    ForEach(store.songSnippets) { state in
                        SongSnippetView(store: .init(initialState: state, reducer: {
                            SongSnippetFeature()
                        }))
                    }
                }
            }
            .navigationTitle("History")
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

#Preview {
    HistoryView(store: .init(initialState: HistoryFeature.State(), reducer: {
        HistoryFeature()
    }))
}

