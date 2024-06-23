// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SQLite

extension Expression {
    
    enum Genres {
        static var id: Expression<Int64> {
            .init("id")
        }
        
        static var name: Expression<String> {
            .init("name")
        }
    }
    
    enum Media {
        static var id: Expression<Int64> {
            .init("id")
        }
        
        static var musicId: Expression<String> {
            .init("musicId")
        }
        
        static var addedDate: Expression<Date> {
            .init("addedDate")
        }
        
        static var artistName: Expression<String> {
            .init("artistName")
        }
        
        static var albumName: Expression<String?> {
            .init("albumName")
        }
        
        static var songName: Expression<String> {
            .init("songName")
        }
        
        static var releaseDate: Expression<Date> {
            .init("releaseDate")
        }
        
        static var albumArtURL: Expression<URL?> {
            .init("albumArtURL")
        }
        
        static var snippetArtDataPath: Expression<Data?> {
            .init("snippetArtDataPath")
        }
        
        static var artistURL: Expression<URL?> {
            .init("artistURL")
        }
        
        static var storeURL: Expression<URL?> {
            .init("storeURL")
        }
        
        static var duration: Expression<TimeInterval> {
            .init("duration")
        }
        
        static var saved: Expression<Bool> {
            .init("saved")
        }
    }
}
