// © BCE Labs, 2024. All rights reserved.
//
//
//import Foundation
////import ComposableArchitecture
//import SwiftData
//
//struct Database: DependencyKey {
//    
//    var context: () -> ModelContext
//    
//    static var liveValue = Self {
//        MyApp.sharedContext
//    }
//    
//    static var previewValue = Self {
//        let context = try! ModelContext(.init(for: Media.self, configurations: .init(isStoredInMemoryOnly: true)))
//        context.insert(Media(artistName: "Test", albumName: "Test", songName: "Test", releaseDate: .now, albumArtURL: .init(string: "https://www.udiscovermusic.com/wp-content/uploads/2015/10/Flamin-Groovies-1024x1024.jpg")!, snippetArtURL: .init(string: "https://www.udiscovermusic.com/wp-content/uploads/2015/10/Flamin-Groovies-1024x1024.jpg")!, artistURL: .init(string: "https://google.com"), storeURL: .init(string: "https://google.com"), genreNames: ["test"], musicId: .init(rawValue: "test")))
//        return context
//    }
//}
//
//extension DependencyValues {
//    
//    var database: Database {
//        get { self[Database.self] }
//        set { self[Database.self] = newValue }
//    }
//}
