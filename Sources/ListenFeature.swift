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

        @Presents var alert: AlertState<Action.Alert>?
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

        case genreTapped(String)
        case alert(PresentationAction<Alert>)

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

        enum Alert: Equatable {
            case hideGenreConfirmed(String)
        }
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
            case .genreTapped(let genre):
                state.alert = AlertState {
                    TextState("Hide this genre?")
                } actions: {
                    ButtonState(role: .destructive, action: .hideGenreConfirmed(genre)) {
                        TextState("Hide")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Songs tagged \(genre) will be skipped. You can unhide it anytime in Settings.")
                }
                return .none
            case .alert(.presented(.hideGenreConfirmed(let genre))):
                var hidden = UserDefaults.standard.hiddenGenres
                if !hidden.contains(genre) {
                    hidden.append(genre)
                    UserDefaults.standard.hiddenGenres = hidden
                }

                // Drop pre-fetched songs that match the newly hidden genre —
                // from the app's lookahead and from the system player's queue.
                // The current song keeps playing.
                let hiddenSet = Set(hidden.map { $0.lowercased() })
                let purged = state.upNext.filter { Self.matchesHiddenGenre($0.media, hidden: hiddenSet) }
                guard !purged.isEmpty else { return .none }

                state.upNext.removeAll { Self.matchesHiddenGenre($0.media, hidden: hiddenSet) }
                return .merge(
                    .send(.mediaPlayer(.removeFromQueue(purged.map(\.song.id)))),
                    .send(.prefetchNextSong)
                )
            case .alert:
                return .none
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

                // Keep playing through a skip only if music was already
                // playing; a skip never starts playback by itself.
                state.pendingPlay = state.mediaPlayer.isPlaying

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

                // Playback never starts on its own at launch — the user has
                // to tap play. Auto Play only keeps an active session going.
                return .send(.prefetchNextSong)
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
        .ifLet(\.$alert, action: \.alert)

        Scope(state: \.mediaPlayer, action: \.mediaPlayer) {
            MediaPlayerFeature()
        }
    }

    static func matchesHiddenGenre(_ media: Media, hidden: Set<String>) -> Bool {
        (media.genreNames ?? []).contains { hidden.contains($0.lowercased()) }
    }

    /// Generates progressively longer words until the catalog search comes up
    /// empty, then resolves the last successful match into a playable `Song`.
    /// Songs in a hidden genre are skipped; a few fresh words are tried
    /// before giving up.
    private func findSong(model: Model) async throws -> QueuedSong {
        let hidden = Set(UserDefaults.standard.hiddenGenres.map { $0.lowercased() })

        for _ in 0..<5 {
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

            if Self.matchesHiddenGenre(media, hidden: hidden) { continue }

            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: id)
            guard let song = try await request.response().items.first else {
                throw SongDiscoveryError.songUnavailable
            }

            return QueuedSong(media: media, song: song)
        }

        throw SongDiscoveryError.noResults
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
            .navigationTitle("Discover")
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
        }
        .refreshable {
            store.send(.skipButtonTapped)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
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

    @ViewBuilder
    private func artworkView(media: Media) -> some View {
        AlbumArtworkView(url: media.albumArtURL)
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

    private var songInfoView: some View {
        VStack(spacing: 4) {
            if let songName = store.currentMediaInformation?.songName {
                Text(songName)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
            } else {
                Text("Loading song")
                    .font(.title.bold())
                    .redacted(reason: .placeholder)
            }

            let subtitle = [
                store.currentMediaInformation?.artistName,
                store.currentMediaInformation?.albumName
            ].compactMap(\.self).joined(separator: " – ")

            if !subtitle.isEmpty {
                MarqueeText(text: subtitle, font: .title2)
            } else {
                Text("Loading artist")
                    .font(.title2)
                    .redacted(reason: .placeholder)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var genrePillsView: some View {
        // "Music" is Apple's catch-all genre on nearly every song — not
        // useful as a pill, and hiding it would hide everything.
        let genres = (store.currentMediaInformation?.genreNames ?? []).filter { $0 != "Music" }
        if !genres.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(genres, id: \.self) { genre in
                        Button {
                            store.send(.genreTapped(genre))
                        } label: {
                            Text(genre)
                                .font(.body)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(pillBackground, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.center)
        }
    }

    private var pillBackground: Color {
#if os(iOS)
        Color(.secondarySystemBackground)
#else
        Color(nsColor: .controlBackgroundColor)
#endif
    }

    private var timestampsView: some View {
        let duration = store.currentMediaInformation?.duration ?? 0
        let elapsed = min(scrubTime ?? store.currentPlaybackTime ?? 0, duration)

        return HStack {
            Text(timeString(elapsed))
            Spacer()
            Text("-" + timeString(max(duration - elapsed, 0)))
        }
        .font(.footnote.monospacedDigit())
    }

    private func timeString(_ interval: TimeInterval) -> String {
        Duration.seconds(max(interval, 0)).formatted(.time(pattern: .minuteSecond))
    }

    private var bottomView: some View {
        VStack(spacing: 12) {
            songInfoView
            genrePillsView

            VStack(spacing: 4) {
                timestampsView
                progressSlider
            }

            HStack(spacing: 20) {
                AirPlayButton()
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: Circle())

                Button {
                    store.send(.playButtonTapped)
                } label: {
                    Image(systemName: store.mediaPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.accentColor).interactive(), in: Capsule())
                .disabled(store.isLoading)

                Button {
                    store.send(.skipButtonTapped)
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
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
