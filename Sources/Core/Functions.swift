// © BCE Labs, 2024. All rights reserved.
//

import MusicKit
import SmallCharacterModel

public func findRandomSong(container: Container) async throws -> MusicXSong {
    container.logger.debug(#function)
    print(container.musicService)
    
    container.appState.uiState.isSearching = true
    defer { container.appState.uiState.isSearching = false }
    
    func findSong(
        container: Container,
        temporarySong: MusicXSong?,
        query: String?
    ) async throws -> MusicXSong? {
        let term = try SCMFunctions.generate(
            prefix: query ?? "",
            length: (query?.count ?? 0) + 1,
            model: container.model.model
        )
        
        container.logger.debug("Requesting: \(term)")
        
        let songs = try await container.musicService.findSongs(
            term: term,
            includeTopResults: container.appState.settings.includeTopResults
        )
        
        if let song = songs.randomElement() {
            return try await findSong(
                container: container,
                temporarySong: song,
                query: term
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
    
    return song
}

public func enqueue(
    song: MusicXSong,
    container: Container
) async throws {
    container.logger.debug(#function)
    container.logger.debug("Enqueueing: \(song.title)")
    
    try await container.musicService.enqueue(song: song)
    container.appState.history.append(song)
    
    print(container.musicService)
}

public func play(container: Container) async throws {
    container.logger.debug(#function)
    switch container.musicService.playbackStatus {
    case .paused:
        try await container.musicService.prepareToPlay()
        try await container.musicService.play()
    case .stopped:
        if container.musicService.queueIsEmpty {
            container.logger.debug("Requested to play with nothing in the queue. Skipping a song")
            try await skipForward(container: container)
        }
    default:
        print("Unhandled play status: \(container.musicService.playbackStatus)")
    }
    
    print(container.musicService)
}

public func pause(container: Container) {
    container.logger.debug(#function)
    container.musicService.pause()
    print(container.musicService)
}

public func skipForward(container: Container) async throws {
    container.logger.debug(#function)
    
    let song = try await findRandomSong(container: container)
    try await container.musicService.enqueue(song: song)
    try await container.musicService.prepareToPlay()
    try await container.musicService.play()
    
    print(container.musicService)
}

public func skipBackward(container: Container) async throws {
    container.logger.debug(#function)
    
    try await container.musicService.skipToPreviousEntry()
    
    print(container.musicService)
}

public func addToHistory(
    song: MusicXSong,
    container: Container
) {
    container.logger.debug(#function)
    
    container.appState.history.append(song)
    
    print(container.musicService)
}

public func removeFromHistory(
    song: MusicXSong,
    container: Container
) {
    container.logger.debug(#function)
    
    container.appState.history.removeAll(where: {
        song.id == $0.id
    })
    
    print(container.musicService)
}

public func bookmark(
    song: MusicXSong,
    container: Container
) {
    container.logger.debug(#function)
    
    container.appState.bookmarks.insert(song)
    
    print(container.musicService)
}

public func removeBookmark(
    song: MusicXSong,
    container: Container
) {
    container.logger.debug(#function)
    
    container.appState.bookmarks.remove(song)
    
    print(container.musicService)
}
