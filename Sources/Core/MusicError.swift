// © BCE Labs, 2024. All rights reserved.
//

enum MusicError: Error {
    case failedToFindSongAndNoTemporaryFallback
    case noResourcesMatching(MusicXSong)
}
