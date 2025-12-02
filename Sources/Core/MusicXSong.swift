// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import MusicKit

public struct MusicXSong: Codable, Hashable, Identifiable, PlayableMusicItem {
    public var playParameters: PlayParameters?
    public var id: MusicItemID
    
    public var title: String
    public var artistName: String
    public var albumTitle: String?
    public var releaseDate: Date?
    public var duration: TimeInterval?
    public var genreNames: [String]
    
    public var albumArtURL: URL?
    public var albumArtThumbnailURL: URL?
    public var artistURL: URL?
    public var url: URL?
    
    public init(
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
