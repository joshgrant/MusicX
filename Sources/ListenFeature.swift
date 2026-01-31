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
        var currentMediaInformation: Media?
        var temporaryMediaInformation: Media?
        
        var currentPlaybackTime: TimeInterval?
        
        var musicSubscription: MusicSubscription?
    }
    
    enum Action {
        case onAppear
        case timerTick
        
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
        
        case playbackStatusChanged(MusicPlayer.PlaybackStatus)
    }
    
    enum CancelID {
        case updateTimer
    }
    
    @Dependency(\.openURL) var openURL
    @Dependency(\.musicService) var musicService
    @Dependency(\.continuousClock) var clock
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    for await _ in self.clock.timer(interval: .seconds(1)) {
                        await send(.timerTick)
                    }
                }
                .cancellable(id: CancelID.updateTimer)
            case .timerTick:
                state.currentPlaybackTime = ApplicationMusicPlayer.shared.playbackTime
                
                guard
                    let duration = state.currentMediaInformation?.duration,
                    let playbackTime = state.currentPlaybackTime
                else {
                    return .none
                }
                
                print("Updated at: \(playbackTime) - song duration: \(duration)")
                
                // If we have auto-play set to false, we don't do anything here
                guard UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.autoPlay.rawValue) else {
                    return .none
                }
                
                /// Our tick function only updates every 1 second, so our margin of error is +/- 1 second
                /// Therefore, we need to give the playback time an additional second of wait, in the worst case
                /// to compensate.
                if Int(playbackTime + 1) >= Int(duration) {
                    return .send(.refreshSong)
                } else {
                    return .none
                }
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
                guard let mediaId = state.currentMediaInformation?.musicId else { return .none }
                @Dependency(\.database) var database
                let context = database.context()
                
                // Fetch the persistent object and modify it
                if let persistentMedia = try? context.fetch(
                    FetchDescriptor<Media>(predicate: #Predicate { $0.musicId == mediaId })
                ).first {
                    persistentMedia.bookmarked.toggle()
                    try? context.save()
                }
                
                // Update the local state to reflect the change
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
                    
                    guard UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.autoPlay.rawValue) else {
                        return .none
                    }
                    
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
            case .playbackStatusChanged(let status):
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
                    if let media = store.currentMediaInformation,
                       let url = media.storeURL {
                        Button {
                            Task {
                                await shareTrack(media: media, url: url)
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            // Disabled state
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(true)
                    }
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
        }
        .refreshable {
            store.send(.refreshSong)
        }
        .onChange(of: state.playbackStatus) { oldValue, newValue in
            store.send(.playbackStatusChanged(newValue))
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
    
    private var albumArtPlaceholderView: some View {
        Image("LoadingView")
            .resizable()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 512)
            .redacted(reason: .placeholder)
    }
    
    private func shareText(for media: Media) -> String {
        var components: [String] = []
        
        if let songName = media.songName {
            components.append(songName)
        }
        
        if let artistName = media.artistName {
            components.append("by \(artistName)")
        }
        
        return components.joined(separator: " ")
    }
    
    @MainActor
    private func shareTrack(media: Media, url: URL) async {
        var itemsToShare: [Any] = []
        
        // Combine text and URL into one string for better compatibility
        var textToShare = "I found this track with MusicX:\n\n"
        textToShare += shareText(for: media)
        textToShare += "\n\nListen on Apple Music:\n"
        textToShare += url.absoluteString
        
        // Add the combined text as a single item
        itemsToShare.append(textToShare)
        
        // Download and add the album artwork if available
        if let artworkURL = media.albumArtURL {
            do {
                let (imageData, _) = try await URLSession.shared.data(from: artworkURL)
                if let image = UIImage(data: imageData) {
                    itemsToShare.append(image)
                }
            } catch {
                print("Failed to download album artwork: \(error)")
            }
        }
        
        // Present the share sheet
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )
        
        // For iPad support
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = rootViewController.view
            popoverController.sourceRect = CGRect(
                x: rootViewController.view.bounds.midX,
                y: rootViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popoverController.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true)
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
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                if let songName = store.currentMediaInformation?.songName {
                    Label(songName, systemImage: "music.note")
                        .font(.title3)
                } else {
                    Text("Loading song")
                        .redacted(reason: .placeholder)
                }
                
                if let artistName = store.currentMediaInformation?.artistName {
                    Label(artistName, systemImage: "person.crop.square")
                } else {
                    Text("Loading artist")
                        .font(.title3)
                        .redacted(reason: .placeholder)
                }
                
                if let albumName = store.currentMediaInformation?.albumName {
                    Label(albumName, systemImage: "rectangle.stack.badge.play")
                        .font(.subheadline)
                } else {
                    Text("Loading album")
                        .font(.subheadline)
                        .redacted(reason: .placeholder)
                }
                
                if let releaseDate = store.currentMediaInformation?.releaseDate {
                    Text(releaseDate.formatted(date: .numeric, time: .omitted))
                } else {
                    Text("Loading date")
                        .redacted(reason: .placeholder)
                }
                
                if let genres = store.currentMediaInformation?.genreNames {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(genres, id: \.self) {
                                Text($0)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                } else {
                    Text("Loading genres")
                        .redacted(reason: .placeholder)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            
            if let duration = store.currentMediaInformation?.duration, let time = store.currentPlaybackTime {
                ProgressView(value: time, total: duration)
                    .animation(.easeInOut(duration: duration - time), value: time)
            } else {
                ProgressView(value: 0, total: 1)
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
                .disabled(store.isLoading)
                
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
                .disabled(store.isLoading)
                
                Button {
                    store.send(.refreshSong)
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.largeTitle)
                }
                .buttonStyle(.plain)
                .disabled(store.isLoading)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
    }
}

#Preview {
    ListenView(store: .init(initialState: ListenFeature.State(), reducer: {
        ListenFeature()
    }))
}

