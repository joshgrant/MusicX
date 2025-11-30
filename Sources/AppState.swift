// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import MusicKit

protocol PlayerProtocol {
    func clearQueue()
    func enqueue(song: AppState.Song) async throws
    func prepareToPlayIfNecessary() async throws
    func pause()
    func play() async throws
    func skipToNextEntry() async throws
    
    func requestAuthorization() async -> Bool
    
    var isAuthorized: Bool { get }
    var isPlaying: Bool { get }
    var hasItemInQueue: Bool { get }
}

extension ApplicationMusicPlayer: PlayerProtocol {

    func prepareToPlayIfNecessary() async throws {
        if !isPreparedToPlay {
            try await prepareToPlay()
        }
    }

    func clearQueue() {
        queue = []
    }
    
    func enqueue(song: AppState.Song) async throws {
        try await queue.insert(song, position: .tail)
    }
    
    var isAuthorized: Bool {
        MusicAuthorization.currentStatus == .authorized
    }
    
    func requestAuthorization() async -> Bool {
        let result = await MusicAuthorization.request()
        switch result {
        case .authorized:
            return true
        default:
            return false
        }
    }
    
    var isPlaying: Bool {
        state.playbackStatus == .playing
    }
    
    var hasItemInQueue: Bool {
        !queue.entries.isEmpty
    }
}

class MockMusicPlayer: PlayerProtocol {
    
    var isPlaying: Bool = false
    var queue: [AppState.Song] = []
    
    var hasItemInQueue: Bool {
        queue.count > 0
    }
    
    func clearQueue() {
        queue = []
    }
    
    func enqueue(song: AppState.Song) async throws {
        queue.append(song)
    }
    
    func prepareToPlayIfNecessary() async throws {}
    
    func pause() {
        isPlaying = false
    }
    
    func play() async throws {
        isPlaying = true
    }
    
    func skipToNextEntry() async throws {
        queue.removeFirst()
    }
    
    func requestAuthorization() async -> Bool {
        return true
    }
     
    var isAuthorized: Bool {
        return true
    }
}

import SmallCharacterModel

// TODO: This is global for now, but let's move it into AppState
var smallCharacterModel = CharacterModelState(source: .preTrainedBundleModel(.init(
    name: "song-titles",
    cohesion: 3,
    fileExtension: "media")))

struct AppState {
    
    enum SearchType: Codable {
        case song
        case album
        case artist
    }
    
    enum RandomMode: Codable {
        case probable
        case chaotic
    }
    
    struct Settings: Codable {
        var searchType: SearchType
        var randomMode: RandomMode
        var autoPlay: Bool
    }
    
    // Persisted to disk
    var settings: Settings
    var history: [AppState.Song]
    var bookmarks: [AppState.Song]
    
    // Stored in memory
    var currentSong: AppState.Song
    var isSearchingForSong: Bool
    
    // Computed
    var canSkipBackward: Bool {
        !history.isEmpty
    }
}

extension AppState {
    
    struct Song: Codable, Identifiable, PlayableMusicItem {
        var playParameters: PlayParameters?
        var id: MusicItemID
        
        var title: String
        var artist: String
        var album: String?
        var releaseDate: Date?
        var duration: TimeInterval?
        var genres: [String]
        
        var albumArtURL: URL?
        var albumArtThumbnailURL: URL?
        var artistURL: URL?
        var storeURL: URL?
    }
}

extension AppState.Song {
    
    public init(
        song: MusicKit.Song
    ) {
        self.id = song.id
        
        self.title = song.title
        self.artist = song.artistName
        self.album = song.albumTitle
        self.releaseDate = song.releaseDate
        self.duration = song.duration
        self.genres = song.genreNames
        
        self.albumArtURL = song.artwork?.url(width: 512, height: 512)
        self.albumArtThumbnailURL = song.artwork?.url(width: 64, height: 64)
        self.artistURL = song.artistURL
        self.storeURL = song.url
    }
}

// To be called when the program starts
func configure(
    player: any PlayerProtocol
) {
    if !player.isAuthorized {
        
    }
//    let result = await MusicAuthorization.request()
//    
//    switch MusicAuthorization.currentStatus {
//    case .authorized
//    }
}

func set(
    searchType: AppState.SearchType,
    on appState: inout AppState
) {
    appState.settings.searchType = searchType
}

func set(
    randomMode: AppState.RandomMode,
    on appState: inout AppState
) {
    appState.settings.randomMode = randomMode
}

func togglePlaying(
    musicPlayer: any PlayerProtocol,
    on appState: inout AppState
) async throws {
    if musicPlayer.isPlaying {
        try await set(isPlaying: false, musicPlayer: musicPlayer, on: &appState)
    } else {
        try await set(isPlaying: true, musicPlayer: musicPlayer, on: &appState)
    }
}

func set(
    isPlaying: Bool,
    musicPlayer: any PlayerProtocol,
    on appState: inout AppState
) async throws {
    if isPlaying {
        try await musicPlayer.play()
    } else {
        musicPlayer.pause()
    }
}

func toggleBookmarked(
    song: AppState.Song,
    on appState: inout AppState
) {
    if appState.bookmarks.contains(where: { $0.id == song.id }) {
        set(isBookmarked: false, song: song, on: &appState)
    } else {
        set(isBookmarked: true, song: song, on: &appState)
    }
}

func set(
    isBookmarked: Bool,
    song: AppState.Song,
    on appState: inout AppState
) {
    if isBookmarked {
        appState.bookmarks.removeAll(where: { $0.id == song.id })
    } else if appState.bookmarks.contains(where: { $0.id == song.id }) {
        return
    } else {
        appState.bookmarks.append(song)
    }
}

func addToHistory(
    song: AppState.Song,
    on appState: inout AppState
) {
    appState.history.append(song)
}

func removeFromHistory(
    song: AppState.Song,
    on appState: inout AppState
) {
    guard let index = appState.history.firstIndex(where: { $0.id == song.id }) else {
        return
    }
    
    appState.history.remove(at: index)
}

func skipForward(
    musicPlayer: any PlayerProtocol,
    appState: inout AppState
) async throws {
    guard musicPlayer.hasItemInQueue else {
        await findAndEnqueueSong(appState: &appState)
        try await set(isPlaying: true, musicPlayer: musicPlayer, on: &appState)
        return
    }
    
    try await musicPlayer.skipToNextEntry()
}

func skipBackward(
    musicPlayer: any PlayerProtocol,
    appState: inout AppState
) async throws {
    guard appState.canSkipBackward else {
        return
    }
    
    if let mostRecent = appState.history.last {
        try await play(song: mostRecent, musicPlayer: musicPlayer, appState: &appState)
    }
}

func play(
    song: AppState.Song,
    musicPlayer: any PlayerProtocol,
    appState: inout AppState
) async throws {
    try await musicPlayer.enqueue(song: song)
    try await musicPlayer.skipToNextEntry()
}

func findAndEnqueueSong(
    appState: inout AppState
) async {
    // 1. Use the character model to come up with a word
    // 2. Search.
    // 3. Determine the results
    // 4. Once we've narrowed down to one, get that song info
    // 5. Add it to the queue
}

func enqueueSong(
    song: AppState.Song,
    mediaPlayer: any PlayerProtocol,
    appState: inout AppState
) async throws {
    try await mediaPlayer.enqueue(song: song)
}
