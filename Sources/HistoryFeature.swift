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
        case toggleBookmark(Media)
        /// Handled by `AppFeature`, which switches to the Discover tab.
        case discoverButtonTapped
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
            case .delete(let media):
                return .run { send in
                    await MainActor.run {
                        let context = database.context()
                        context.delete(media)
                        try? context.save()
                    }
                }
            case .toggleBookmark(let media):
                return .run { send in
                    await MainActor.run {
                        media.bookmarked.toggle()
                        try? media.modelContext?.save()
                    }
                }
            case .discoverButtonTapped:
                return .none
            }
        }
    }
}

import SwiftUI
import SwiftData
import Combine

struct HistoryView: View {
    
    @Bindable var store: StoreOf<HistoryFeature>
    
    @Query var media: [Media]
    
    var body: some View {
        NavigationStack {
            Group {
                if snippets.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(snippets.reversed()) { state in
                            SongSnippetView(store: .init(initialState: state, reducer: {
                                SongSnippetFeature()
                            }))
                            .swipeActions {
                                Button {
                                    store.send(.toggleBookmark(state.media), animation: .snappy)
                                } label: {
                                    Label("", systemImage: "bookmark.fill")
                                }
                                .tint(Color.accentColor)

                                Button(role: .destructive) {
                                    store.send(.delete(state.media), animation: .snappy)
                                } label: {
                                    Label("", systemImage: "trash.fill")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: media) { oldValue, newValue in
            store.send(.gotFetchResults(newValue))
        }
    }
    
    // On macOS this list doubles as the Saved view via the filter picker,
    // so the empty state follows the active filter.
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(
                store.showingOnlyBookmarks ? "No Saved Songs" : "No History Yet",
                systemImage: store.showingOnlyBookmarks ? "bookmark.fill" : "clock.fill")
        } description: {
            Text(store.showingOnlyBookmarks
                 ? "Bookmark a song in Discover and it'll show up here."
                 : "Every song you play in Discover lands here.")
        } actions: {
            Button("Discover More Music") {
                store.send(.discoverButtonTapped)
            }
            .buttonStyle(.borderedProminent)
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

