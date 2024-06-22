// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SmallCharacterModel
import MusicKit
import SwiftData
import Combine

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
//        var currentMediaInformation: Media?
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
        
        case fetchedMediaInformation(word: String, searchResults: [Media])
        case foundNextSong(word: String, mediaInformation: Media)
        
        case authorized(MusicAuthorization.Status)
        case failedToAuthenticate(Error)
        
        case playbackStatusChanged(MusicPlayer.PlaybackStatus, TimeInterval)
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
                if let url = musicService.currentSong()?.url {
                    return .run { send in
                        await openURL(url)
                    }
                } else {
                    return .none
                }
            case .saveToFavoritesToggled:
                return .run { send in
                    @Dependency(\.database) var database
                    let request = FetchDescriptor<Media>(predicate: #Predicate { input in
                        input.musicId?.rawValue == musicService.currentSong()?.id.rawValue
                    })
                    guard let mediaItem = await database.context().fetch(request).first else {
                        XCTFail("Shouldn't save to favorites if the song doesn't exist")
                        return
                    }
                    mediaItem.bookmarked.toggle()
                }
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
                return .run { send in
                    do {
                        let mediaInformation = try await musicService.search(word)
                        await send(.fetchedMediaInformation(word: word, searchResults: mediaInformation))
                    } catch {
                        await send(.failedToAuthenticate(error))
                    }
                }
            case .smallCharacterModel:
                return .none
            case .fetchedMediaInformation(let word, let mediaInformation):
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
                    return .send(.foundNextSong(word: word, mediaInformation: foundSong))
                }
            case .foundNextSong(let word, let media):
                print("FOUND SONG: \(word)")
                if let id = media.musicId {
                    state.currentMediaInformation = media
                    return .send(.mediaPlayer(.enqueueMedia(id)))
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
            case .playbackStatusChanged(let status, let time):
                state.currentPlaybackTime = time
                switch status {
                case .stopped:
                    print("STOPPED")
                case .playing:
                    print("PLAYING")
                case .paused:
                    print("PAUSED")
                case .interrupted:
                    print("INTERRUPTED")
                case .seekingForward:
                    print("SEEKING F")
                case .seekingBackward:
                    print("SEEKING B")
                @unknown default:
                    print("DEFAULT")
                }
                return .none
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
    @ObservedObject var state = ApplicationMusicPlayer.shared.state
    
    var playbackStatus: ApplicationMusicPlayer.PlaybackStatus {
        state.playbackStatus
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let progress = store.buildProgress {
                    albumArtPlaceholderView
                    ProgressView("Loading Model", value: progress)
                } else if store.isLoading {
                    albumArtPlaceholderView
                    ProgressView()
                        .controlSize(.large)
                } else if let mediaInformation = store.currentMediaInformation {
                    artworkView(media: mediaInformation)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .safeAreaInset(edge: .bottom, content: {
                bottomView
            })
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
            .onChange(of: playbackStatus) { oldValue, newValue in
                store.send(.playbackStatusChanged(newValue, ApplicationMusicPlayer.shared.playbackTime))
                
                
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
    private func artworkView(media: Media) -> some View {
        AsyncImage(url: media.albumArtURL) { image in
            image
                .resizable()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .aspectRatio(1, contentMode: .fit)
        } placeholder: {
            albumArtPlaceholderView
        }
        .frame(maxWidth: 512, maxHeight: 512)
    }
    
    private var bottomView: some View {
        VStack {
            if let media = store.currentMediaInformation {
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
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(genres, id: \.self) {
                                    Text($0)
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                }
                
                if let duration = media.duration, let time = store.currentPlaybackTime {
                    ProgressView(value: time, total: duration)
                        .animation(.easeInOut(duration: duration - time), value: time)
                }
            }
            
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
//                        store.send(.mediaPlayer(.enqueueMedia(id)))
                        store.send(.mediaPlayer(.play))
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
        .frame(maxWidth: .infinity)
        .padding(16)
        .disabled(store.isLoading)
        .background(.thickMaterial)
    }
}

#Preview {
    ListenView(store: .init(initialState: ListenFeature.State(), reducer: {
        ListenFeature()
    }))
}

