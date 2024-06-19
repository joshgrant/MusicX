// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SmallCharacterModel
import MusicKit

@Reducer
struct ListenFeature {
    
    @ObservableState
    struct State: Equatable {
        var smallCharacterModel = SmallCharacterModel.State(source: .preTrainedBundleModel(.init(
            name: "song-titles",
            cohesion: 3,
            fileExtension: "media")))
        
        var mediaPlayer = MediaPlayerFeature.State()
        
        var buildProgress: Double?
        
        var isLoading: Bool = true
        var currentQuery: String? = nil
        var currentMediaInformation: MediaInformation?
        var temporaryMediaInformation: MediaInformation?
        var currentPlaybackTime: TimeInterval?
        var isBookmarked: Bool = false
        var isPlaying: Bool = false
        
        var musicSubscription: MusicSubscription?
    }
    
    enum Action {
        case smallCharacterModel(SmallCharacterModel.Action)
        case mediaPlayer(MediaPlayerFeature.Action)
        
        case openSongURL
        case saveToFavoritesToggled
        
        case togglePlaying
        case refreshSong
        case songFinishedPlaying
        
        case attemptToLoadFirstSong
        
        case fetchedMediaInformation([MediaInformation])
        case foundNextSong(mediaInformation: MediaInformation)
        
        case authorized(MusicAuthorization.Status)
        case failedToAuthenticate(Error)
    }
    
    @Dependency(\.openURL) var openURL
    @Dependency(\.musicService) var musicService
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .authorized(let status):
                switch status {
                case .authorized:
                    return .send(.attemptToLoadFirstSong)
                default:
                    fatalError()
                }
            case .openSongURL:
                if let url = state.currentMediaInformation?.storeURL {
                    return .run { send in
                        await openURL(url)
                    }
                } else {
                    return .none
                }
            case .saveToFavoritesToggled:
                state.isBookmarked.toggle()
                return .none
            case .togglePlaying:
                state.isPlaying.toggle()
                return .none
            case .refreshSong:
                state.isLoading = true
                // Start with 2 just to reduce API calls
                return .send(.smallCharacterModel(.wordGenerator(.generate(prefix: "", length: 5))))
            case .songFinishedPlaying:
                return .none
                // Small character model
            case .smallCharacterModel(.modelLoader(.delegate(.modelLoadingFailed(let error)))):
                print(error)
                guard state.buildProgress == nil else {
                    return .none
                }
                fatalError(error.localizedDescription)
            case .smallCharacterModel(.modelBuilder(.delegate(.progress(let progress)))):
                state.buildProgress = progress
                return .none
            case .smallCharacterModel(.modelBuilder(.delegate(.saved))):
                state.buildProgress = nil
                return .send(.attemptToLoadFirstSong)
            case .smallCharacterModel(.modelLoader(.delegate(.loaded))):
                state.buildProgress = nil
                return .send(.attemptToLoadFirstSong)
            case .smallCharacterModel(.wordGenerator(.delegate(.newWord(let word)))):
                state.currentQuery = word
                print("SET WORD: \(word)")
                return .run { send in
                    do {
                        let mediaInformation = try await musicService.search(word)
                        await send(.fetchedMediaInformation(mediaInformation))
                    } catch {
                        await send(.failedToAuthenticate(error))
                    }
                }
            case .smallCharacterModel:
                return .none
            case .fetchedMediaInformation(let mediaInformation):
                // TODO: If media information is longer than 1 element, store a random element, generate a new letter, and fetch more
                // TODO: If media information is 0 elements long, return the last random element...
                
                if let element = mediaInformation.randomElement() {
                    state.temporaryMediaInformation = element
                    print("FETCHED: \(element)")
                    return .send(.smallCharacterModel(.wordGenerator(.generate(
                        prefix: state.currentQuery ?? "",
                        length: (state.currentQuery?.count ?? 0) + 1))))
                } else {
                    guard let foundSong = state.temporaryMediaInformation else {
                        fatalError("There was no temporary media information")
                    }
                    state.isLoading = false
                    return .send(.foundNextSong(mediaInformation: foundSong))
                }
            case .foundNextSong(let mediaInformation):
                state.currentMediaInformation = mediaInformation
                if let song = mediaInformation.song {
                    return .send(.mediaPlayer(.enqueue(song)))
                } else {
                    return .none
                }
            case .failedToAuthenticate(let error):
                return .run { send in
                    let result = await MusicAuthorization.request()
                    await send(.authorized(result))
                }
            case .mediaPlayer:
                return .none
            case .attemptToLoadFirstSong:
                if state.buildProgress != nil {
                    return .none
                }
                
                if musicService.authorizationStatus() != .authorized {
                    return .none
                }
                
                return .send(.refreshSong)
            }
        }
        
        Scope(state: \.smallCharacterModel, action: \.smallCharacterModel) {
            SmallCharacterModel()
        }
        
        Scope(state: \.mediaPlayer, action: \.mediaPlayer) {
            MediaPlayerFeature()
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
                    if let progress = store.buildProgress {
                        albumArtPlaceholderView
                        ProgressView("Loading Model", value: progress)
                    } else if store.isLoading {
                        albumArtPlaceholderView
                        ProgressView()
                            .controlSize(.large)
                    } else if let mediaInformation = store.currentMediaInformation {
                        AsyncImage(url: mediaInformation.albumArtURL) { image in
                            image
                                .resizable()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .aspectRatio(1, contentMode: .fit)
                        } placeholder: {
                            albumArtPlaceholderView
                        }
                        
                        VStack(spacing: 4) {
                            Text(mediaInformation.artistName)
                            
                            if let albumName = mediaInformation.albumName {
                                Text(albumName)
                            }
                            
                            Text(mediaInformation.songName)
                            
                            if let releaseDate = mediaInformation.releaseDate {
                                Text(releaseDate.formatted(date: .numeric, time: .omitted))
                            }
                        }
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
                            
                            // TODO: Fix me?
                            Button {
                                if !store.mediaPlayer.isPlaying, let song = store.currentMediaInformation {
                                    store.send(.mediaPlayer(.play(song)))
                                } else {
                                    store.send(.mediaPlayer(.pause))
                                }
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
                                store.send(.refreshSong)
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.largeTitle)
                            }
                        }
                    }
                    .disabled(store.isLoading)
                    
                    // Progress view here for the playback progress
                    
                    Spacer()
                }
                .padding(16)
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
                    .disabled(store.state.currentMediaInformation == nil)
                }
                
                ToolbarItem {
                    Button {
                        store.send(.openSongURL)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .disabled(store.state.currentMediaInformation == nil)
                }
            }
            .refreshable {
                store.send(.refreshSong)
            }
        }
    }
    
    private var albumArtPlaceholderView: some View {
        Rectangle()
            .fill(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ListenView(store: .init(initialState: ListenFeature.State(), reducer: {
        ListenFeature()
    }))
}

