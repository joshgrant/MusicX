// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SmallCharacterModel
import MusicKit
import SwiftData
import Combine

/// A discovered song, with the MusicKit `Song` already resolved so playback can start immediately.
struct QueuedSong: Equatable {
    let media: Media
    let song: Song
}

@Reducer
struct ListenFeature {

    @ObservableState
    struct State: Equatable {
        var mediaPlayer = MediaPlayerFeature.State()

        var model: Model?

        var isLoading: Bool = true
        var isFetchingFirstSong: Bool = false
        var currentMediaInformation: Media?
        var currentSong: Song?
        var errorMessage: String?

        // Pre-fetch pipeline: resolved songs waiting to play, oldest first.
        var upNext: [QueuedSong] = []
        var isPrefetching: Bool = false
        var pendingAdvance: Bool = false
        var pendingPlay: Bool = false

        var currentPlaybackTime: TimeInterval?

        var musicSubscription: MusicSubscription?
    }

    enum Action {
        case onAppear
        case timerTick

        case loadModel
        case modelLoaded(Model)
        case modelLoadFailed(String)

        case mediaPlayer(MediaPlayerFeature.Action)

        case openSongURL
        case saveToFavoritesToggled

        case playButtonTapped
        case skipButtonTapped
        case seek(TimeInterval)

        case attemptToLoadFirstSong
        case firstSongLoaded(QueuedSong)
        case firstSongFailed

        case prefetchNextSong
        case nextSongPrefetched(QueuedSong)
        case prefetchFailed(String)

        case advanceToNextSong
        case songFinished

        case playerEntryChanged(MusicItemID?)

        case authorized(MusicAuthorization.Status)
        case playbackStatusChanged(MusicPlayer.PlaybackStatus)
    }

    /// How many songs to keep resolved (and queued in the system player)
    /// ahead of the current one, so playback can continue while the app
    /// is suspended in the background.
    static let lookaheadCount = 3

    enum CancelID {
        case updateTimer
    }

    enum SongDiscoveryError: Error {
        case noResults
        case songUnavailable
    }

    @Dependency(\.openURL) var openURL
    @Dependency(\.musicService) var musicService
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .send(.mediaPlayer(.onAppear)),
                    .run { send in
                        for await _ in self.clock.timer(interval: .seconds(1)) {
                            await send(.timerTick)
                        }
                    }
                    .cancellable(id: CancelID.updateTimer, cancelInFlight: true)
                )
            case .timerTick:
                let previousTime = state.currentPlaybackTime ?? 0
                let currentTime = musicService.playbackTime()
                state.currentPlaybackTime = currentTime

                // If the system player advanced to a queued entry on its own
                // (e.g. while the app was in the background), catch up first.
                if let entryID = musicService.currentEntryID(),
                   entryID != state.currentSong?.id,
                   state.upNext.contains(where: { $0.song.id == entryID }) {
                    return .send(.playerEntryChanged(entryID))
                }

                // Fallback end-of-song detection: the player can reset its
                // playback time to 0 when the queue finishes, so compare the
                // last observed time against the duration as well.
                let status = musicService.playbackStatus()
                if state.mediaPlayer.isPlaying,
                   status == .paused || status == .stopped,
                   let duration = state.currentMediaInformation?.duration,
                   max(previousTime, currentTime) >= duration - 2 {
                    state.mediaPlayer.isPlaying = false
                    return .send(.songFinished)
                }

                return .none
            case .loadModel:
                return .run { send in
                    let source = ModelSource.preTrainedBundleModel(.init(
                        name: "song-titles",
                        cohesion: 3,
                        fileExtension: "media"))
                    let characterModel = try CharacterModelState(source: source)
                    await send(.modelLoaded(characterModel.model))
                } catch: { error, send in
                    await send(.modelLoadFailed(error.localizedDescription))
                }
            case .modelLoaded(let model):
                state.model = model
                return .send(.attemptToLoadFirstSong)
            case .modelLoadFailed(let message):
                state.isLoading = false
                state.errorMessage = "Failed to load the song model: \(message)"
                return .none
            case .authorized(let status):
                switch status {
                case .authorized:
                    return .send(.attemptToLoadFirstSong)
                default:
                    state.isLoading = false
                    state.errorMessage = "MusicX needs access to Apple Music to discover songs. You can grant access in Settings."
                    return .none
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
                // `Media` is a reference type that was already inserted into
                // the shared context, so toggle it directly and save.
                guard let media = state.currentMediaInformation else { return .none }
                @Dependency(\.database) var database
                media.bookmarked.toggle()
                try? database.context().save()
                return .none
            case .playButtonTapped:
                if state.mediaPlayer.isPlaying {
                    return .send(.mediaPlayer(.pause))
                }

                guard let song = state.currentSong else { return .none }

                if state.mediaPlayer.queuedSongID == song.id {
                    return .send(.mediaPlayer(.resume))
                }

                return .send(.mediaPlayer(.play([song] + state.upNext.map(\.song))))
            case .skipButtonTapped:
                guard state.currentMediaInformation != nil else { return .none }

                state.pendingPlay = state.mediaPlayer.isPlaying || autoPlayEnabled

                if !state.upNext.isEmpty {
                    return .send(.advanceToNextSong)
                }

                // The next song isn't ready yet: show the loading state and
                // advance as soon as the pre-fetch completes.
                state.isLoading = true
                state.pendingAdvance = true
                return .send(.prefetchNextSong)
            case .songFinished:
                guard autoPlayEnabled else { return .none }

                state.pendingPlay = true

                if !state.upNext.isEmpty {
                    return .send(.advanceToNextSong)
                }

                state.isLoading = true
                state.pendingAdvance = true
                return .send(.prefetchNextSong)
            case .seek(let time):
                state.currentPlaybackTime = time
                return .send(.mediaPlayer(.seek(time)))
            case .attemptToLoadFirstSong:
                guard let model = state.model,
                      musicService.authorizationStatus() == .authorized,
                      state.currentMediaInformation == nil,
                      !state.isFetchingFirstSong
                else {
                    return .none
                }

                state.isFetchingFirstSong = true
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        let queued = try await findSong(model: model)
                        await send(.firstSongLoaded(queued))
                    } catch {
                        print("Failed to load the first song: \(error)")
                        await send(.firstSongFailed)
                    }
                }
            case .firstSongLoaded(let queued):
                state.isFetchingFirstSong = false
                state.isLoading = false
                state.currentMediaInformation = queued.media
                state.currentSong = queued.song
                state.currentPlaybackTime = 0
                insertIntoHistory(queued.media)

                var effects: [Effect<Action>] = [.send(.prefetchNextSong)]
                if autoPlayEnabled {
                    effects.insert(.send(.mediaPlayer(.play([queued.song]))), at: 0)
                }
                return .merge(effects)
            case .firstSongFailed:
                state.isFetchingFirstSong = false
                state.isLoading = false
                state.errorMessage = "Couldn't find a song to play. Check your connection and try again."
                return .none
            case .prefetchNextSong:
                guard let model = state.model,
                      !state.isPrefetching,
                      state.upNext.count < Self.lookaheadCount
                else {
                    return .none
                }

                state.isPrefetching = true
                return .run { send in
                    do {
                        let queued = try await findSong(model: model)
                        await send(.nextSongPrefetched(queued))
                    } catch {
                        await send(.prefetchFailed(error.localizedDescription))
                    }
                }
            case .nextSongPrefetched(let queued):
                state.isPrefetching = false
                state.upNext.append(queued)

                if state.pendingAdvance {
                    return .send(.advanceToNextSong)
                }

                // Keep filling the lookahead, and mirror it into the system
                // player's queue (when the player is in sync with the UI) so
                // playback continues while the app is suspended.
                var effects: [Effect<Action>] = [.send(.prefetchNextSong)]
                if state.mediaPlayer.queuedSongID == state.currentSong?.id,
                   state.currentSong != nil {
                    effects.append(.send(.mediaPlayer(.enqueue(queued.song))))
                }
                return .merge(effects)
            case .prefetchFailed(let message):
                print("Failed to pre-fetch the next song: \(message)")
                state.isPrefetching = false
                state.pendingAdvance = false
                state.pendingPlay = false
                state.isLoading = false
                return .none
            case .advanceToNextSong:
                guard !state.upNext.isEmpty else { return .none }

                let next = state.upNext.removeFirst()
                state.pendingAdvance = false
                state.isLoading = false
                state.currentMediaInformation = next.media
                state.currentSong = next.song
                state.currentPlaybackTime = 0
                insertIntoHistory(next.media)

                let play = state.pendingPlay
                state.pendingPlay = false

                var effects: [Effect<Action>] = [.send(.prefetchNextSong)]
                if play {
                    effects.insert(.send(.mediaPlayer(.play([next.song] + state.upNext.map(\.song)))), at: 0)
                }
                return .merge(effects)
            case .playerEntryChanged(let entryID):
                // The system player advanced on its own — typically because a
                // queued entry started while the app was suspended. Catch the
                // app state up to whatever the player is on now.
                guard let entryID,
                      entryID != state.currentSong?.id,
                      let index = state.upNext.firstIndex(where: { $0.song.id == entryID })
                else {
                    return .none
                }

                for played in state.upNext.prefix(index) {
                    insertIntoHistory(played.media)
                }

                let current = state.upNext[index]
                state.upNext.removeFirst(index + 1)
                state.currentMediaInformation = current.media
                state.currentSong = current.song
                state.mediaPlayer.queuedSongID = current.song.id
                state.currentPlaybackTime = musicService.playbackTime()
                state.mediaPlayer.isPlaying = musicService.playbackStatus() == .playing
                insertIntoHistory(current.media)

                var effects: [Effect<Action>] = [.send(.prefetchNextSong)]

                // If the player exhausted its queue while we were suspended,
                // resume the auto-play chain from here.
                let status = musicService.playbackStatus()
                if autoPlayEnabled,
                   status == .paused || status == .stopped,
                   let duration = current.media.duration,
                   musicService.playbackTime() >= duration - 2 {
                    state.mediaPlayer.isPlaying = false
                    effects.append(.send(.songFinished))
                }
                return .merge(effects)
            case .playbackStatusChanged(let status):
                // If the system player advanced to a queued entry on its own,
                // reconcile before interpreting the status change.
                if let entryID = musicService.currentEntryID(),
                   entryID != state.currentSong?.id,
                   state.upNext.contains(where: { $0.song.id == entryID }) {
                    return .send(.playerEntryChanged(entryID))
                }

                switch status {
                case .playing:
                    state.mediaPlayer.isPlaying = true
                    return .none
                case .paused, .stopped:
                    let wasPlaying = state.mediaPlayer.isPlaying
                    state.mediaPlayer.isPlaying = false

                    guard wasPlaying,
                          let duration = state.currentMediaInformation?.duration
                    else {
                        return .none
                    }

                    // The player can reset its playback time to 0 when the
                    // queue finishes, so fall back to the last observed time.
                    let time = max(state.currentPlaybackTime ?? 0, musicService.playbackTime())
                    if time >= duration - 2 {
                        return .send(.songFinished)
                    }

                    return .none
                default:
                    return .none
                }
            case .mediaPlayer:
                return .none
            }
        }

        Scope(state: \.mediaPlayer, action: \.mediaPlayer) {
            MediaPlayerFeature()
        }
    }

    /// Generates progressively longer words until the catalog search comes up
    /// empty, then resolves the last successful match into a playable `Song`.
    private func findSong(model: Model) async throws -> QueuedSong {
        var word = try SCMFunctions.generate(prefix: "", length: 5, model: model)
        var candidate: Media?

        while true {
            let results = try await musicService.search(word)
            guard let element = results.randomElement() else { break }

            candidate = element

            guard let longer = try? SCMFunctions.generate(
                prefix: word,
                length: word.count + 1,
                model: model),
                  longer != word
            else { break }

            word = longer
        }

        guard let media = candidate, let id = media.musicId else {
            throw SongDiscoveryError.noResults
        }

        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: id)
        guard let song = try await request.response().items.first else {
            throw SongDiscoveryError.songUnavailable
        }

        return QueuedSong(media: media, song: song)
    }

    private func insertIntoHistory(_ media: Media) {
        @Dependency(\.database) var database
        let context = database.context()
        context.insert(media)
        try? context.save()
    }

    private var autoPlayEnabled: Bool {
        UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.autoPlay.rawValue)
    }
}

import SwiftUI

struct ListenView: View {

    @Bindable var store: StoreOf<ListenFeature>
    @ObservedObject var state = ApplicationMusicPlayer.shared.state
    @ObservedObject var queue = ApplicationMusicPlayer.shared.queue

    @Environment(\.scenePhase) private var scenePhase

    @State private var scrubTime: TimeInterval?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if store.isLoading {
                    albumArtPlaceholderView
                    ProgressView()
                        .controlSize(.large)
                } else if let errorMessage = store.errorMessage {
                    ContentUnavailableView {
                        Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") {
                            store.send(.attemptToLoadFirstSong)
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
#if os(iOS)
                        Button {
                            Task {
                                await shareTrack(media: media, url: url)
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
#else
                        ShareLink(item: url, message: Text(shareText(for: media))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
#endif
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
            store.send(.skipButtonTapped)
        }
        .onChange(of: state.playbackStatus) { oldValue, newValue in
            store.send(.playbackStatusChanged(newValue))
        }
        .onChange(of: queue.currentEntry) { oldValue, newValue in
            store.send(.playerEntryChanged(newValue?.item?.id))
        }
        .onChange(of: scenePhase) { oldValue, newValue in
            // Re-sync with the system player after the app was suspended:
            // it may have advanced through queued songs on its own.
            if newValue == .active {
                store.send(.playerEntryChanged(queue.currentEntry?.item?.id))
            }
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

#if os(iOS)
    @MainActor
    private func shareTrack(media: Media, url: URL) async {
        var itemsToShare: [Any] = []

        let textToShare = """
        I found this track with MusicX:

        \(shareText(for: media))

        Listen on Apple Music:
        \(url.absoluteString)
        """

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
#endif

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

    @ViewBuilder
    private var progressSlider: some View {
        if let duration = store.currentMediaInformation?.duration, duration > 0 {
            Slider(
                value: Binding(
                    get: { min(scrubTime ?? store.currentPlaybackTime ?? 0, duration) },
                    set: { scrubTime = $0 }
                ),
                in: 0...duration
            ) { editing in
                if !editing, let time = scrubTime {
                    store.send(.seek(time))
                    scrubTime = nil
                }
            }
            .disabled(store.currentSong == nil)
        } else {
            Slider(value: .constant(0), in: 0...1)
                .disabled(true)
        }
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

            progressSlider

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

                Button {
                    store.send(.playButtonTapped)
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
                    store.send(.skipButtonTapped)
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
