// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture

@Reducer
struct ListenFeature {
    
    struct MediaInformation: Equatable {
        var albumArt: Image
        var artistName: String
        var albumName: String
        var songName: String
        var releaseDate: String
    }
    
    @ObservableState
    struct State: Equatable {
        var isLoading: Bool = true
        var mediaInformation: MediaInformation?
        var currentPlaybackTime: TimeInterval?
        var isBookmarked: Bool = false
        var isPlaying: Bool = false
    }
    
    enum Action {
        case openInAppleMusic
        case saveToFavoritesToggled
        
        case togglePlaying
        case skip
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .openInAppleMusic:
                return .none
            case .saveToFavoritesToggled:
                state.isBookmarked.toggle()
                return .none
            case .togglePlaying:
                state.isPlaying.toggle()
                return .none
            case .skip:
                return .none
            }
        }
    }
}

import SwiftUI

struct ListenView: View {
    
    @Bindable var store: StoreOf<ListenFeature>
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.isLoading {
                        Rectangle()
                            .fill(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .aspectRatio(1, contentMode: .fit)
                            .padding(16)
                        
                        ProgressView()
                            .controlSize(.large)
                    } else if let mediaInformation = store.mediaInformation {
                        mediaInformation.albumArt
                        
                        Text(mediaInformation.artistName)
                        Text(mediaInformation.albumName)
                        Text(mediaInformation.songName)
                        Text(mediaInformation.releaseDate)
                    }
                    
                    Group {
                        HStack(spacing: 40) {
                            // This is just for layout purposes
                            Button {
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.largeTitle)
                            }
                            .opacity(0)
                            
                            Button {
                                store.send(.togglePlaying)
                            } label: {
                                if store.isPlaying {
                                    Image(systemName: "pause.fill")
                                        .font(.largeTitle)
                                } else {
                                    Image(systemName: "play.fill")
                                        .font(.largeTitle)
                                }
                            }
                            
                            Button {
                                store.send(.skip)
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.largeTitle)
                            }
                        }
                        
                        ProgressView()
                            .progressViewStyle(.linear)
                            .padding(16)
                    }
                    .disabled(store.isLoading)
                    
                    Spacer()
                }
            }
            .navigationTitle("Listen")
            .toolbar {
                ToolbarItem {
                    Button {
                        store.send(.saveToFavoritesToggled)
                    } label: {
                        if store.isBookmarked {
                            Image(systemName: "bookmark.fill")
                        } else {
                            Image(systemName: "bookmark")
                        }
                    }
                }
                
                ToolbarItem {
                    Button {
                        store.send(.openInAppleMusic)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                }
            }
        }
    }
}

#Preview {
    ListenView(store: .init(initialState: ListenFeature.State(), reducer: {
        ListenFeature()
    }))
}

