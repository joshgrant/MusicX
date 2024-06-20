// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SmallCharacterModel
import MusicKit
import SwiftData

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
        var currentMediaInformation: Media?
        var temporaryMediaInformation: Media?
        var currentPlaybackTime: TimeInterval?
        
        var musicSubscription: MusicSubscription?
    }
    
    enum Action {
        case smallCharacterModel(SmallCharacterModel.Action)
        case mediaPlayer(MediaPlayerFeature.Action)
        
        case openSongURL
        case saveToFavoritesToggled
        
        case refreshSong
        
        case attemptToLoadFirstSong
        
        case fetchedMediaInformation([Media])
        case foundNextSong(mediaInformation: Media)
        
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
                state.currentMediaInformation?.bookmarked.toggle()
                return .none
            case .refreshSong:
                state.isLoading = true
                // Start with 2 just to reduce API calls
                return .send(.smallCharacterModel(.wordGenerator(.generate(prefix: "", length: 5))))
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
                if let element = mediaInformation.randomElement() {
                    state.temporaryMediaInformation = element
                    return .send(.smallCharacterModel(.wordGenerator(.generate(
                        prefix: state.currentQuery ?? "",
                        length: (state.currentQuery?.count ?? 0) + 1))))
                } else {
                    guard let foundSong = state.temporaryMediaInformation else {
                        fatalError("There was no temporary media information")
                    }
                    state.isLoading = false
                    @Dependency(\.database) var database
                    database.context().insert(foundSong)
                    return .send(.foundNextSong(mediaInformation: foundSong))
                }
            case .foundNextSong(let media):
                if let id = media.musicId {
                    state.currentMediaInformation = media
                    return .send(.mediaPlayer(.playMedia(id)))
                } else {
                    fatalError()
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
    
    @ObservedObject private var playerState = ApplicationMusicPlayer.shared.state
    
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
                        artistView(media: mediaInformation)
                    }
                    
                    playbackControls
                    
                    ProgressView(value: ApplicationMusicPlayer.shared.playbackTime, total: ApplicationMusicPlayer.shared.queue.currentEntry?.endTime ?? 1)
                    
                    // TODO: Progress view here for the playback progress
                    
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
                        if store.currentMediaInformation?.bookmarked ?? false {
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
            .frame(maxWidth: 512)
    }
    
    @ViewBuilder
    private func artistView(media: Media) -> some View {
        AsyncImage(url: media.albumArtURL) { image in
            image
                .resizable()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .aspectRatio(1, contentMode: .fit)
        } placeholder: {
            albumArtPlaceholderView
        }
        .frame(maxWidth: 512, maxHeight: 512)
        
        VStack(spacing: 4) {
            if let artistName = media.artistName {
                Text(artistName)
            }
            
            if let albumName = media.albumName {
                Text(albumName)
            }
            
            if let songName = media.songName {
                Text(songName)
            }
            
            if let releaseDate = media.releaseDate {
                Text(releaseDate.formatted(date: .numeric, time: .omitted))
            }
            
            if let genres = media.genreNames {
                ForEach(genres, id: \.self) {
                    Text($0)
                }
            }
        }
    }
    
    private var playbackControls: some View {
        Group {
            HStack(spacing: 40) {
                // This is just for layout purposes
                Button {
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.largeTitle)
                }
                .buttonStyle(.plain)
                .opacity(0)
                
                // TODO: Fix me?
                Button {
                    if !store.mediaPlayer.isPlaying,
                       let media = store.currentMediaInformation,
                        let id = media.musicId {
                        store.send(.mediaPlayer(.playMedia(id)))
                    } else {
                        store.send(.mediaPlayer(.pause))
                    }
                } label: {
                    if store.mediaPlayer.isPlaying {
                        Image(systemName: "pause.fill")
                            .font(.largeTitle)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.largeTitle)
                    }
                }
                .buttonStyle(.plain)
                
                Button {
                    store.send(.refreshSong)
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.largeTitle)
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(store.isLoading)
    }
}

#Preview {
    ListenView(store: .init(initialState: ListenFeature.State(), reducer: {
        ListenFeature()
    }))
}

