// © BCE Labs, 2024. All rights reserved.
//

import MusicKit
import SmallCharacterModel

public func findRandomSong(container: Container) async throws -> MusicXSong {
    container.logger.debug(#function)
    container.appState.uiState.isSearching = true
    
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
        
        switch container.appState.settings.searchType {
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
        request.includeTopResults = container.appState.settings.includeTopResults
        
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
    
    container.appState.uiState.isSearching = false
    return song
}

public func enqueue(
    song: MusicXSong,
    container: Container
) async throws {
    container.logger.debug(#function)
    container.logger.debug("Enqueueing and playing: \(song.title)")
    
    try await container.musicService.enqueue(song: song)
    
    container.appState.history.append(song)
}

public func play(container: Container) async throws {
    container.logger.debug(#function)
    try await container.musicService.prepareToPlay()
    try await container.musicService.play()
}

public func pause(container: Container) {
    container.logger.debug(#function)
    container.musicService.pause()
}

public func skipForward(container: Container) async throws {
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

public func skipBackward(container: Container) async throws {
    container.logger.debug(#function)
    try await container.musicService.skipToPreviousEntry()
}

public func addToHistory(
    song: MusicXSong,
    container: Container
) {
    container.logger.debug(#function)
    container.appState.history.append(song)
}

public func removeFromHistory(
    song: MusicXSong,
    container: Container
) {
    container.logger.debug(#function)
    container.appState.history.removeAll(where: {
        song.id == $0.id
    })
}

public func bookmark(
    song: MusicXSong,
    container: Container
) {
    container.logger.debug(#function)
    container.appState.bookmarks.insert(song)
}

public func removeBookmark(
    song: MusicXSong,
    container: Container
) {
    container.logger.debug(#function)
    container.appState.bookmarks.remove(song)
}
