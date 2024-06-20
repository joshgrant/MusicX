// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SwiftData

@Reducer
struct SavedFeature {
    
    @ObservableState
    struct State: Equatable {
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
                    let predicate: Predicate<Media> = #Predicate {
                        $0.bookmarked
                    }
                    let descriptor = FetchDescriptor<Media>(predicate: predicate, sortBy: [.init(\.timestamp)])
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
            }
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
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(store.songSnippets.reversed()) { state in
                        SongSnippetView(store: .init(initialState: state, reducer: {
                            SongSnippetFeature()
                        }))
                    }
                }
                .padding(16)
            }
            .navigationTitle("Saved")
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

#Preview {
    SavedView(store: .init(initialState: SavedFeature.State(), reducer: {
        SavedFeature()
    }))
}

