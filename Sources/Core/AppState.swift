// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import MusicKit
import SmallCharacterModel
import OSLog

//let logger = Logger(subsystem: "core", category: "general")
//
//public protocol PlayerProtocol {
//    func clearQueue()
//    func enqueue(song: MusicXSong) async throws
//    func prepareToPlayIfNecessary() async throws
//    func pause()
//    func play() async throws
//    func skipToNextEntry() async throws
//    
//    func requestAuthorization() async -> Bool
//    
//    var isAuthorized: Bool { get }
//    var isPlaying: Bool { get }
//    var hasItemInQueue: Bool { get }
//    var currentSong: MusicXSong? { get }
//}
//
//extension ApplicationMusicPlayer: PlayerProtocol {
//    
//    public func prepareToPlayIfNecessary() async throws {
//        if !isPreparedToPlay {
//            try await prepareToPlay()
//        }
//    }
//    
////    public func clearQueue() {
////        queue = []
////    }
////    
//    public func enqueue(song: MusicXSong) async throws {
//        if queue.entries.isEmpty {
//            queue = [song]
//        } else {
//            try await queue.insert(song, position: .tail)
//        }
//    }
//    
//    public func enqueue(song: MusicKit.Song) async throws {
//        try await queue.insert(song, position: .tail)
//    }
//    
//    public var isAuthorized: Bool {
//        MusicAuthorization.currentStatus == .authorized
//    }
//    
//    public func requestAuthorization() async -> Bool {
//        let result = await MusicAuthorization.request()
//        switch result {
//        case .authorized:
//            return true
//        default:
//            return false
//        }
//    }
//    
//    public var isPlaying: Bool {
//        state.playbackStatus == .playing
//    }
//    
//    public var hasItemInQueue: Bool {
//        !queue.entries.isEmpty
//    }
//    
//    public var currentSong: MusicXSong? {
//        switch queue.currentEntry?.item {
//        case .song(let song):
//            return .init(song: song)
//        default:
//            return nil
//        }
//    }
//}

//class MockMusicPlayer: PlayerProtocol {
//    
//    var isPlaying: Bool = false
//    var queue: [MusicXSong] = []
//    
//    var hasItemInQueue: Bool {
//        queue.count > 0
//    }
//    
//    public func clearQueue() {
//        queue = []
//    }
//    
//    public func enqueue(song: MusicXSong) async throws {
//        queue.append(song)
//    }
//    
//    //    func enqueue(song: MusicKit.Song) {
//    //        queue.append(.init(song: song))
//    //    }
//    
//    public func prepareToPlayIfNecessary() async throws {}
//    
//    public func pause() {
//        isPlaying = false
//    }
//    
//    public func play() async throws {
//        isPlaying = true
//    }
//    
//    public func skipToNextEntry() async throws {
//        queue.removeFirst()
//    }
//    
//    public func requestAuthorization() async -> Bool {
//        return true
//    }
//    
//    var isAuthorized: Bool {
//        return true
//    }
//    
//    var currentSong: MusicXSong? {
//        // TODO: Return a fake song
//        nil
//    }
//}
//
//var appState = AppState(
//    model: CharacterModelState(source: .preTrainedBundleModel(.init(
//        name: "song-titles",
//        cohesion: 3,
//        fileExtension: "media")))
//)
//
//public class AppState {
//    
//    public enum SearchType: Codable {
//        case song
//        case album
//        case artist
//    }
//    
//    public enum RandomMode: Codable {
//        case probable
//        case chaotic
//    }
//    
//    public struct Settings: Codable {
//        var searchType: SearchType
//        var randomMode: RandomMode
//        var autoPlay: Bool
//    }
//    
//    public var model: CharacterModelState
//    
//    // Persisted to disk
//    public var settings: Settings
//    public var history: [MusicXSong]
//    public var bookmarks: [MusicXSong]
//    
//    // Stored in memory
//    public var isSearchingForSong: Bool
//    
//    // Computed
//    public var canSkipBackward: Bool {
//        !history.isEmpty
//    }
//    
//    public init(
//        model: CharacterModelState,
//        settings: Settings? = nil,
//        history: [MusicXSong] = [],
//        bookmarks: [MusicXSong] = [],
//        isSearchingForSong: Bool = false
//    ) {
//        self.model = model
//        self.settings = settings ?? .init(searchType: .song, randomMode: .probable, autoPlay: true)
//        self.history = history
//        self.bookmarks = bookmarks
//        self.isSearchingForSong = isSearchingForSong
//    }
//    
//}

//public extension AppState {
//    
//    // To be called when the program starts
//    static func configure(
//        player: any PlayerProtocol,
//        appState: AppState
//    ) async throws {
//        logger.debug("\(#function)")
//        
//        try SCMFunctions.load(state: &appState.model)
//        
//        let result = await MusicAuthorization.request()
//        
//        switch result {
//        case .authorized:
//            player.clearQueue()
//        default:
//            fatalError()
//        }
//    }
//    
//    static func set(
//        searchType: AppState.SearchType,
//        on appState: AppState
//    ) {
//        logger.debug("\(#function)")
//        
//        appState.settings.searchType = searchType
//    }
//    
//    static func set(
//        randomMode: AppState.RandomMode,
//        on appState: AppState
//    ) {
//        logger.debug("\(#function)")
//        
//        appState.settings.randomMode = randomMode
//    }
//    
//    static func togglePlaying(
//        musicPlayer: any PlayerProtocol,
//        on appState: AppState
//    ) async throws {
//        logger.debug("\(#function)")
//        
//        if musicPlayer.isPlaying {
//            try await set(isPlaying: false, musicPlayer: musicPlayer, on: appState)
//        } else {
//            try await set(isPlaying: true, musicPlayer: musicPlayer, on: appState)
//        }
//    }
//    
//    static func set(
//        isPlaying: Bool,
//        musicPlayer: any PlayerProtocol,
//        on appState: AppState
//    ) async throws {
//        logger.debug("\(#function)")
//        
//        if isPlaying {
//            try await musicPlayer.play()
//        } else {
//            musicPlayer.pause()
//        }
//    }
//    
//    static func toggleBookmarked(
//        song: MusicXSong,
//        on appState: AppState
//    ) {
//        logger.debug("\(#function)")
//        
//        if appState.bookmarks.contains(where: { $0.id == song.id }) {
//            set(isBookmarked: false, song: song, on: appState)
//        } else {
//            set(isBookmarked: true, song: song, on: appState)
//        }
//    }
//    
//    static func set(
//        isBookmarked: Bool,
//        song: MusicXSong,
//        on appState: AppState
//    ) {
//        logger.debug("\(#function)")
//        
//        if isBookmarked {
//            
//            if appState.bookmarks.contains(where: { $0.id == song.id }) {
//                return
//            } else {
//                appState.bookmarks.append(song)
//            }
//            
//        } else {
//            appState.bookmarks.removeAll(where: { $0.id == song.id })
//        }
//    }
//    
//    static func addToHistory(
//        song: MusicXSong,
//        on appState: AppState
//    ) {
//        logger.debug("\(#function)")
//        
//        appState.history.append(song)
//    }
//    
//    static func removeFromHistory(
//        song: MusicXSong,
//        on appState: AppState
//    ) {
//        logger.debug("\(#function)")
//        
//        guard let index = appState.history.firstIndex(where: { $0.id == song.id }) else {
//            return
//        }
//        
//        appState.history.remove(at: index)
//    }
//    
//    static func skipForward(
//        musicPlayer: any PlayerProtocol,
//        appState: AppState
//    ) async throws {
//        logger.debug("\(#function)")
//        
//        guard musicPlayer.hasItemInQueue else {
//            try await findAndEnqueueSong(musicPlayer: musicPlayer, appState: appState)
//            try await set(isPlaying: true, musicPlayer: musicPlayer, on: appState)
//            return
//        }
//        
//        try await ApplicationMusicPlayer.shared.prepareToPlay()
//        try await musicPlayer.skipToNextEntry()
//    }
//    
//    static func skipBackward(
//        musicPlayer: any PlayerProtocol,
//        appState: AppState
//    ) async throws {
//        logger.debug("\(#function)")
//        
//        guard appState.canSkipBackward else {
//            return
//        }
//        
//        if let mostRecent = appState.history.last {
//            removeFromHistory(song: mostRecent, on: appState)
//            try await play(song: mostRecent, musicPlayer: musicPlayer, appState: appState)
//        }
//    }


// MARK: - Revision 2

public struct MusicXSong: Codable, Identifiable, PlayableMusicItem {
    public var playParameters: PlayParameters?
    public var id: MusicItemID
    
    var title: String
    var artistName: String
    var albumTitle: String?
    var releaseDate: Date?
    var duration: TimeInterval?
    var genreNames: [String]
    
    var albumArtURL: URL?
    var albumArtThumbnailURL: URL?
    var artistURL: URL?
    var url: URL?
    
    init(
        song: MusicKit.Song,
        artworkSize: Int = 512,
        thumbnailSize: Int = 64
    ) {
        self.playParameters = song.playParameters
        self.id = song.id
        self.title = song.title
        self.artistName = song.artistName
        self.albumTitle = song.albumTitle
        self.releaseDate = song.releaseDate
        self.duration = song.duration
        self.genreNames = song.genreNames
        self.albumArtURL = song.artwork?.url(width: artworkSize, height: artworkSize)
        self.albumArtThumbnailURL = song.artwork?.url(width: thumbnailSize, height: thumbnailSize)
        self.artistURL = song.artistURL
        self.url = song.url
    }
}

enum MusicError: Error {
    case failedToFindSongAndNoTemporaryFallback
    case noResourcesMatching(MusicXSong)
}

enum MusicAuthorizationStatus {
    
    case notDetermined
    case denied
    case restricted
    case authorized
    
    init(musicAuthorizationStatus: MusicAuthorization.Status) {
        switch musicAuthorizationStatus {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .authorized: self = .authorized
        default:
            self = .notDetermined
        }
    }
}

enum MusicPlaybackStatus {
    case stopped
    case playing
    case paused
    case interrupted
    case seekingForward
    case seekingBackward
    
    init(applicationPlaybackStatus: ApplicationMusicPlayer.PlaybackStatus) {
        switch applicationPlaybackStatus {
        case .stopped: self = .stopped
        case .playing: self = .playing
        case .paused: self = .paused
        case .interrupted: self = .interrupted
        case .seekingForward: self = .seekingForward
        case .seekingBackward: self = .seekingBackward
        @unknown default:
            self = .stopped
        }
    }
}

protocol MusicService {
    var authorizationStatus: MusicAuthorizationStatus { get }
    var queueIsEmpty: Bool { get }
    var playbackStatus: MusicPlaybackStatus { get }
    var currentSong: MusicXSong? { get }
    
    @discardableResult
    func requestAuthorization() async -> MusicAuthorization.Status
    func prepareToPlay() async throws
    func enqueue(song: MusicXSong) async throws
    func play() async throws
    func pause()
    func skipToNextEntry() async throws
    func skipToPreviousEntry() async throws
}

extension ApplicationMusicPlayer: MusicService {

    var authorizationStatus: MusicAuthorizationStatus {
        .init(musicAuthorizationStatus: MusicAuthorization.currentStatus)
    }
    
    var queueIsEmpty: Bool {
        queue.entries.isEmpty
    }
    
    var playbackStatus: MusicPlaybackStatus {
        .init(applicationPlaybackStatus: ApplicationMusicPlayer.shared.state.playbackStatus)
    }
    
    var currentSong: MusicXSong? {
        switch queue.currentEntry?.item {
        case .song(let song):
            return .init(song: song)
        default:
            return nil
        }
    }
    
    @discardableResult
    func requestAuthorization() async -> MusicAuthorization.Status {
        switch MusicAuthorization.currentStatus {
        case .notDetermined:
            return await MusicAuthorization.request()
        default:
            return MusicAuthorization.currentStatus
        }
    }
    
    func enqueue(song: MusicXSong) async throws {
        if queueIsEmpty {
            queue = [song]
        } else {
            try await queue.insert(song, position: .tail)
        }
    }
}

@Observable
public class Application: Codable {
    
    public struct Settings: Codable {
        
        public enum SearchType: Codable {
            case song
            case album
            case artist
        }
        
        public enum RandomMode: Codable {
            case probable
            case chaotic
        }
        
        var searchType: SearchType
        var randomMode: RandomMode
        var autoPlay: Bool
        var includeTopResults: Bool
    }
    
    public class UIState: Codable {
        var isSearching: Bool
        
        init(isSearching: Bool) {
            self.isSearching = isSearching
        }
    }
    
    public var settings: Settings
    public var history: [MusicXSong]
    public var bookmarks: [MusicXSong]
    public var uiState: UIState
    
    init(
        settings: Settings,
        history: [MusicXSong],
        bookmarks: [MusicXSong],
        uiState: UIState
    ) {
        self.settings = settings
        self.history = history
        self.bookmarks = bookmarks
        self.uiState = uiState
    }
}

public class Container {
    let logger: Logger
    let model: CharacterModelState
    let musicService: MusicService
    let application: Application
    
    init(
        logger: Logger,
        model: CharacterModelState,
        musicService: MusicService,
        application: Application
    ) throws {
        self.logger = logger
        self.model = model
        self.musicService = musicService
        self.application = application
    }
}

func findRandomSong(container: Container) async throws -> MusicXSong {
    container.logger.debug(#function)
    container.application.uiState.isSearching = true
    
    func findSong(
        container: Container,
        temporarySong: MusicXSong?,
        query: String?
    ) async throws -> MusicXSong? {
        let word = try SCMFunctions.generate(
            prefix: query ?? "",
            length: (query?.count ?? 0) + 1,
            model: container.model.model
        )
        
        container.logger.debug("Requesting: \(word)")
        
        let types: [any MusicCatalogSearchable.Type]
        
        switch container.application.settings.searchType {
        case .song:
            types = [Song.self]
        case .album:
            types = [Album.self]
        case .artist:
            types = [Artist.self]
        }
        
        var request = MusicCatalogSearchRequest(
            term: word,
            types: types
        )
        request.limit = 5
        request.includeTopResults = container.application.settings.includeTopResults
        
        let response = try await request.response()
        
        if let element = response.songs.randomElement() {
            return try await findSong(
                container: container,
                temporarySong: .init(song: element),
                query: word
            )
        } else {
            return temporarySong
        }
    }
    
    guard let song = try await findSong(
        container: container,
        temporarySong: nil,
        query: nil
    ) else {
        throw MusicError.failedToFindSongAndNoTemporaryFallback
    }
    
    container.application.uiState.isSearching = false
    return song
}

func enqueue(
    song: MusicXSong,
    container: Container
) async throws {
    container.logger.debug(#function)
    container.logger.debug("Enqueueing and playing: \(song.title)")
    
    try await container.musicService.enqueue(song: song)
    
    container.application.history.append(song)
}

func play(container: Container) async throws {
    container.logger.debug(#function)
    try await container.musicService.prepareToPlay()
    try await container.musicService.play()
}

func pause(container: Container) {
    container.logger.debug(#function)
    container.musicService.pause()
}

func skipForward(container: Container) async throws {
    container.logger.debug(#function)
    
    if container.musicService.queueIsEmpty {
        container.logger.debug("Skip forward requesting a new song")
        let song = try await findRandomSong(container: container)
        try await enqueue(song: song, container: container)
        try await play(container: container)
    } else {
        try await container.musicService.skipToNextEntry()
    }
}

// MARK: - Implementation

public func globalFunction() async throws {
    
    // 1. Initialize
    let container = try Container(
        logger: .init(subsystem: "MusicX", category: "General"),
        model: .init(source: .preTrainedBundleModel(.init(
            name: "song-titles",
            cohesion: 3,
            fileExtension: "media")
        )),
        musicService: ApplicationMusicPlayer.shared,
        application: .init(
            settings: .init(
                searchType: .song,
                randomMode: .probable,
                autoPlay: true,
                includeTopResults: true
            ),
            history: [],
            bookmarks: [],
            uiState: .init(isSearching: false)
        )
    )
    
    // 1. We first request authorization
    
    await container.musicService.requestAuthorization()
    
//    try await scenarioA(container: container)
    
    try await skipForward(container: container)
}

func scenarioA(container: Container) async throws {
    // 1. On app launch, we kick off "finding a song"
    // 1a: Show the "Loading state" in the UI
    let song = try await findRandomSong(container: container)
    // 2. Populate the UI with the song
    
    // 3. The user presses "play" (verify the song is in the history)
    try await enqueue(song: song, container: container)
    try await play(container: container)
    
    try await Task.sleep(for: .seconds(2))
    
    // 4. The user presses "pause"
    pause(container: container)
    
    // 5. The user presses "play"
    
    try await Task.sleep(for: .seconds(1))
    
    try await play(container: container)
    
    // 6. The user hits "skip"
    let song2 = try await findRandomSong(container: container)
    try await enqueue(song: song2, container: container)
    try await play(container: container)
    
    try await Task.sleep(for: .seconds(5))
    
    try await skipForward(container: container)
}
