// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import MusicKit

struct MediaInformation: Equatable {
    var artistName: String
    var albumName: String?
    var songName: String
    var releaseDate: Date?
    
    var albumArtURL: URL?
    var artistURL: URL?
    var storeURL: URL?
}

extension MediaInformation {
    
    init(song: Song, artworkSize: Int = 512) {
        self.artistName = song.artistName
        self.albumName = song.albumTitle
        self.songName = song.title
        self.releaseDate = song.releaseDate
        self.albumArtURL = song.artwork?.url(width: artworkSize, height: artworkSize)
        self.artistURL = song.artistURL
        self.storeURL = song.url
    }
}
