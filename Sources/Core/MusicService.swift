// © BCE Labs, 2024. All rights reserved.
//

public protocol MusicService {
    var authorizationStatus: MusicAuthorizationStatus { get }
    var queueIsEmpty: Bool { get }
    var playbackStatus: MusicPlaybackStatus { get }
    var currentSong: MusicXSong? { get }
    
    @discardableResult
    func requestAuthorization() async -> MusicAuthorizationStatus
    func prepareToPlay() async throws
    func enqueue(song: MusicXSong) async throws
    func play() async throws
    func pause()
    func skipToNextEntry() async throws
    func skipToPreviousEntry() async throws
}
