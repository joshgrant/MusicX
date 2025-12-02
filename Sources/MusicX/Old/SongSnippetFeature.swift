//// © BCE Labs, 2024. All rights reserved.
////
//
//import Foundation
//import ComposableArchitecture
//import SwiftUI
//import MusicKit
//import SwiftData
//
//@Reducer
//struct SongSnippetFeature {
//    
//    @ObservableState
//    struct State: Equatable, Identifiable {
//        var media: Media
//        
//        var id: PersistentIdentifier {
//            media.persistentModelID
//        }
//    }
//    
//    enum Action {
//        case openInStore
//        case toggleBookmarked(Bool)
//    }
//    
//    @Dependency(\.openURL) var openURL
//    
//    var body: some ReducerOf<Self> {
//        Reduce { state, action in
//            switch action {
//            case .openInStore:
//                if let url = state.media.storeURL {
//                    return .run { _ in
//                        await openURL(url)
//                    }
//                }
//                return .none
//            case .toggleBookmarked(let bookmarked):
//                return .run { [media = state.media] send in
//                    await MainActor.run {
//                        media.bookmarked = bookmarked
//                    }
//                }
//            }
//        }
//    }
//    
//}
//
//struct SongSnippetView: View {
//    let store: StoreOf<SongSnippetFeature>
//    
//    var body: some View {
//        HStack {
//            if let artURL = store.state.media.snippetArtURL {
//                AsyncImage(url: artURL) { image in
//                    image
//                        .resizable()
//                        .clipShape(RoundedRectangle(cornerRadius: 2))
//                        .aspectRatio(1, contentMode: .fit)
//                } placeholder: {
//                    ProgressView()
//                }
//                .frame(width: 64, height: 64)
//            }
//            
//            if let songName = store.state.media.songName {
//                Text(songName)
//                    .font(.title2)
//            }
//            Spacer()
//            
//            if store.state.media.bookmarked {
//                Button {
//                    store.send(.toggleBookmarked(!store.state.media.bookmarked))
//                } label: {
//                    Image(systemName: "bookmark.fill")
//                }
//                .buttonStyle(.plain)
//            }
//            
//            Button {
//                store.send(.openInStore)
//            } label: {
//                Image(systemName: "arrow.up.right.square")
//            }
//            .buttonStyle(.plain)
//        }
//    }
//}
//
//#Preview {
//    SongSnippetView(store: .init(initialState: SongSnippetFeature.State(media: .init(
//        artistName: "Preview",
//        songName: "Test",
//        snippetArtURL: .init(string: "https://www.udiscovermusic.com/wp-content/uploads/2015/10/Flamin-Groovies-1024x1024.jpg"),
//        musicId: .init(rawValue: "Fake"))), reducer: {
//        SongSnippetFeature()
//    }))
//}
