// © BCE Labs, 2024. All rights reserved.
//

import Observation

public protocol MusicService: Observable, CustomStringConvertible, CustomDebugStringConvertible {
    var authorizationStatus: MusicAuthorizationStatus { get }
    var queueIsEmpty: Bool { get }
    var playbackStatus: MusicPlaybackStatus { get }
    var currentSong: MusicXSong? { get }
    
    @discardableResult
    func requestAuthorization() async -> MusicAuthorizationStatus
    func findSongs(
        term: String,
        includeTopResults: Bool
    ) async throws -> [MusicXSong]
    func prepareToPlay() async throws
    func enqueue(song: MusicXSong) async throws
    func play() async throws
    func pause()
    func stop()
    func skipToNextEntry() async throws
    func skipToPreviousEntry() async throws
}
