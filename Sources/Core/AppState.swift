// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import MusicKit
import SmallCharacterModel
import OSLog

let logger = Logger(subsystem: "core", category: "general")

public protocol PlayerProtocol {
    func clearQueue()
    func enqueue(song: MusicXSong) async throws
    func prepareToPlayIfNecessary() async throws
    func pause()
    func play() async throws
    func skipToNextEntry() async throws
    
    func requestAuthorization() async -> Bool
    
    var isAuthorized: Bool { get }
    var isPlaying: Bool { get }
    var hasItemInQueue: Bool { get }
    var currentSong: MusicXSong? { get }
}

extension ApplicationMusicPlayer: PlayerProtocol {
    
    public func prepareToPlayIfNecessary() async throws {
        if !isPreparedToPlay {
            try await prepareToPlay()
        }
    }
    
    public func clearQueue() {
        queue = []
    }
    
    public func enqueue(song: MusicXSong) async throws {
        if queue.entries.isEmpty {
            queue = [song]
        } else {
            try await queue.insert(song, position: .tail)
        }
    }
    
    public func enqueue(song: MusicKit.Song) async throws {
        try await queue.insert(song, position: .tail)
    }
    
    public var isAuthorized: Bool {
        MusicAuthorization.currentStatus == .authorized
    }
    
    public func requestAuthorization() async -> Bool {
        let result = await MusicAuthorization.request()
        switch result {
        case .authorized:
            return true
        default:
            return false
        }
    }
    
    public var isPlaying: Bool {
        state.playbackStatus == .playing
    }
    
    public var hasItemInQueue: Bool {
        !queue.entries.isEmpty
    }
    
    public var currentSong: MusicXSong? {
        switch queue.currentEntry?.item {
        case .song(let song):
            return .init(song: song)
        default:
            return nil
        }
    }
}

class MockMusicPlayer: PlayerProtocol {
    
    var isPlaying: Bool = false
    var queue: [MusicXSong] = []
    
    var hasItemInQueue: Bool {
        queue.count > 0
    }
    
    public func clearQueue() {
        queue = []
    }
    
    public func enqueue(song: MusicXSong) async throws {
        queue.append(song)
    }
    
//    func enqueue(song: MusicKit.Song) {
//        queue.append(.init(song: song))
//    }
    
    public func prepareToPlayIfNecessary() async throws {}
    
    public func pause() {
        isPlaying = false
    }
    
    public func play() async throws {
        isPlaying = true
    }
    
    public func skipToNextEntry() async throws {
        queue.removeFirst()
    }
    
    public func requestAuthorization() async -> Bool {
        return true
    }
    
    var isAuthorized: Bool {
        return true
    }
    
    var currentSong: MusicXSong? {
        // TODO: Return a fake song
        nil
    }
}

var appState = AppState(
    model: CharacterModelState(source: .preTrainedBundleModel(.init(
        name: "song-titles",
        cohesion: 3,
        fileExtension: "media")))
)

public class AppState {
    
    public enum SearchType: Codable {
        case song
        case album
        case artist
    }
    
    public enum RandomMode: Codable {
        case probable
        case chaotic
    }
    
    public struct Settings: Codable {
        var searchType: SearchType
        var randomMode: RandomMode
        var autoPlay: Bool
    }
    
    public var model: CharacterModelState
    
    // Persisted to disk
    public var settings: Settings
    public var history: [MusicXSong]
    public var bookmarks: [MusicXSong]
    
    // Stored in memory
    public var isSearchingForSong: Bool
    
    // Computed
    public var canSkipBackward: Bool {
        !history.isEmpty
    }
    
    public init(
        model: CharacterModelState,
        settings: Settings? = nil,
        history: [MusicXSong] = [],
        bookmarks: [MusicXSong] = [],
        isSearchingForSong: Bool = false
    ) {
        self.model = model
        self.settings = settings ?? .init(searchType: .song, randomMode: .probable, autoPlay: true)
        self.history = history
        self.bookmarks = bookmarks
        self.isSearchingForSong = isSearchingForSong
    }
    
}

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
    
    init(song: MusicKit.Song) {
        self.playParameters = song.playParameters
        self.id = song.id
        self.title = song.title
        self.artistName = song.artistName
        self.albumTitle = song.albumTitle
        self.releaseDate = song.releaseDate
        self.duration = song.duration
        self.genreNames = song.genreNames
        self.albumArtURL = song.artwork?.url(width: 512, height: 512)
        self.albumArtThumbnailURL = song.artwork?.url(width: 64, height: 64)
        self.artistURL = song.artistURL
        self.url = song.url
    }
}

public extension AppState {
    
    // To be called when the program starts
    static func configure(
        player: any PlayerProtocol,
        appState: AppState
    ) async throws {
        logger.debug("\(#function)")
        
        try SCMFunctions.load(state: &appState.model)
        
        let result = await MusicAuthorization.request()
        
        switch result {
        case .authorized:
            player.clearQueue()
        default:
            fatalError()
        }
    }
    
    static func set(
        searchType: AppState.SearchType,
        on appState: AppState
    ) {
        logger.debug("\(#function)")
        
        appState.settings.searchType = searchType
    }
    
    static func set(
        randomMode: AppState.RandomMode,
        on appState: AppState
    ) {
        logger.debug("\(#function)")
        
        appState.settings.randomMode = randomMode
    }
    
    static func togglePlaying(
        musicPlayer: any PlayerProtocol,
        on appState: AppState
    ) async throws {
        logger.debug("\(#function)")
        
        if musicPlayer.isPlaying {
            try await set(isPlaying: false, musicPlayer: musicPlayer, on: appState)
        } else {
            try await set(isPlaying: true, musicPlayer: musicPlayer, on: appState)
        }
    }
    
    static func set(
        isPlaying: Bool,
        musicPlayer: any PlayerProtocol,
        on appState: AppState
    ) async throws {
        logger.debug("\(#function)")
        
        if isPlaying {
            try await musicPlayer.play()
        } else {
            musicPlayer.pause()
        }
    }
    
    static func toggleBookmarked(
        song: MusicXSong,
        on appState: AppState
    ) {
        logger.debug("\(#function)")
        
        if appState.bookmarks.contains(where: { $0.id == song.id }) {
            set(isBookmarked: false, song: song, on: appState)
        } else {
            set(isBookmarked: true, song: song, on: appState)
        }
    }
    
    static func set(
        isBookmarked: Bool,
        song: MusicXSong,
        on appState: AppState
    ) {
        logger.debug("\(#function)")
        
        if isBookmarked {
            
            if appState.bookmarks.contains(where: { $0.id == song.id }) {
                return
            } else {
                appState.bookmarks.append(song)
            }
            
        } else {
            appState.bookmarks.removeAll(where: { $0.id == song.id })
        }
    }
    
    static func addToHistory(
        song: MusicXSong,
        on appState: AppState
    ) {
        logger.debug("\(#function)")
        
        appState.history.append(song)
    }
    
    static func removeFromHistory(
        song: MusicXSong,
        on appState: AppState
    ) {
        logger.debug("\(#function)")
        
        guard let index = appState.history.firstIndex(where: { $0.id == song.id }) else {
            return
        }
        
        appState.history.remove(at: index)
    }
    
    static func skipForward(
        musicPlayer: any PlayerProtocol,
        appState: AppState
    ) async throws {
        logger.debug("\(#function)")
        
        guard musicPlayer.hasItemInQueue else {
            try await findAndEnqueueSong(musicPlayer: musicPlayer, appState: appState)
            try await set(isPlaying: true, musicPlayer: musicPlayer, on: appState)
            return
        }
        
        try await ApplicationMusicPlayer.shared.prepareToPlay()
        try await musicPlayer.skipToNextEntry()
    }
    
    static func skipBackward(
        musicPlayer: any PlayerProtocol,
        appState: AppState
    ) async throws {
        logger.debug("\(#function)")
        
        guard appState.canSkipBackward else {
            return
        }
        
        if let mostRecent = appState.history.last {
            removeFromHistory(song: mostRecent, on: appState)
            try await play(song: mostRecent, musicPlayer: musicPlayer, appState: appState)
        }
    }
    
    static func play(
        song: MusicXSong,
        musicPlayer: any PlayerProtocol,
        appState: AppState
    ) async throws {
        logger.debug("\(#function)")
        
        let request = MusicCatalogResourceRequest<MusicKit.Song>(
            matching: \.id,
            equalTo: song.id)
        
        print("Playing: \(song.id) \(song.title)")
        
        if let song = try await request.response().items.first {
            try await musicPlayer.enqueue(song: .init(song: song))
            try await musicPlayer.prepareToPlayIfNecessary()
            try await musicPlayer.play()
        } else {
            fatalError()
        }
    }
    
    static func findAndEnqueueSong(
        musicPlayer: any PlayerProtocol,
        appState: AppState
    ) async throws {
        logger.debug("\(#function)")
        
        appState.isSearchingForSong = true
        defer { appState.isSearchingForSong = false }
        
        // Start with 5 characters since we'll usually find something
        let word = try SCMFunctions.generate(
            prefix: "",
            length: 4,
            model: appState.model.model!)
        
        guard let song = try await findSong(
            appState: appState,
            temporarySong: nil,
            query: word)
        else {
            assertionFailure("Didn't find a song!")
            return
        }
        
        try await musicPlayer.enqueue(song: song)
    }
    
    static func findSong(
        appState: AppState,
        temporarySong: MusicXSong?,
        query: String?
    ) async throws -> MusicXSong? {
        logger.debug("\(#function)")
        
        appState.isSearchingForSong = true
        
        let word = try SCMFunctions.generate(
            prefix: query ?? "",
            length: (query?.count ?? 0) + 1,
            model: appState.model.model!)
        
        logger.debug("Requesting: \(word)")
        
        var request = MusicCatalogSearchRequest(
            term: word,
            types: [MusicKit.Song.self])
        request.limit = 5
        
        let response = try await request.response()
        
        // Search until there are no more results
        if let element = response.songs.randomElement() {
            logger.debug("Found a matching song!")
            return try await findSong(
                appState: appState,
                temporarySong: .init(song: element),
                query: word)
        } else {
            logger.debug("No song found, falling back.")
            return temporarySong
        }
    }
}

// MARK: - Revision 2

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
    
    init(applicationPlaybackStatus: ApplicationMusicPlayer.shared.state.playbackStatus) {
        switch applicationPlaybackStatus {
        case .
        }
    }
}

protocol MusicService {
    
    var authorizationStatus: MusicAuthorizationStatus { get }
    var queueIsEmpty: Bool { get }
    var playbackStatus: PlaybackStatus { get }
    var currentSong: MusicXSong? { get }
    
    func requestAuthorization() async -> Bool
    func clearQueue()
    func prepareToPlay() async throws
    func enqueue(song: MusicXSong) async throws
}

extension ApplicationMusicPlayer: MusicService {
    
    var authorizationStatus: MusicAuthorizationStatus {
        .init(musicAuthorizationStatus: MusicAuthorization.currentStatus)
    }
    
    var queueIsEmpty: Bool {
        queue.entries.currentEntry == nil
    }
    
    var playbackStatus: PlaybackStatus {
        
    }
}

@MainActor
public class ApplicationState: @MainActor Codable {
    
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
    }
    
    @Observable
    public class UIState: Codable {
        var isSearching: Bool
        
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
