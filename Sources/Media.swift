//
//  Item.swift
//  MusicBox
//
//  Created by Me on 6/9/24.
//

import Foundation
import SwiftData
import MusicKit

@Model
final class Media {
    
    var timestamp: Date?
    
    var artistName: String?
    var albumName: String?
    var songName: String?
    var releaseDate: Date?
    
    var albumArtURL: URL?
    var snippetArtURL: URL?
    var artistURL: URL?
    var storeURL: URL?
    
    var genreNames: [String]?
    
    var musicId: MusicItemID?
    
    init(
        artistName: String,
        albumName: String? = nil,
        songName: String,
        releaseDate: Date? = nil,
        albumArtURL: URL? = nil,
        snippetArtURL: URL? = nil,
        artistURL: URL? = nil,
        storeURL: URL? = nil,
        genreNames: [String] = [],
        musicId: MusicItemID
    ) {
        self.timestamp = .now
        self.artistName = artistName
        self.albumName = albumName
        self.songName = songName
        self.releaseDate = releaseDate
        self.albumArtURL = albumArtURL
        self.snippetArtURL = snippetArtURL
        self.artistURL = artistURL
        self.storeURL = storeURL
        self.genreNames = genreNames
        self.musicId = musicId
    }
    
    convenience init(song: Song, fullArtworkSize: Int = 512, snippetArtworkSize: Int = 64) {
        self.init(
            artistName: song.artistName,
            albumName: song.albumTitle,
            songName: song.title,
            releaseDate: song.releaseDate,
            albumArtURL: song.artwork?.url(width: fullArtworkSize, height: fullArtworkSize),
            snippetArtURL: song.artwork?.url(width: snippetArtworkSize, height: snippetArtworkSize),
            artistURL: song.artistURL,
            storeURL: song.url,
            genreNames: song.genreNames,
            musicId: song.id)
    }
}
