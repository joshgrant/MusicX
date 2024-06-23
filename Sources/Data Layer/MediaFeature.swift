// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SQLite

@Reducer
public struct MediaFeature {
    
    public struct State: Equatable {
        public var table: IdentifiedTable?
        
        public init() {}
    }
    
    public enum Action {
        case createTable
    }
    
    @Dependency(\.connection) var connection
    
    public init() {}
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .createTable:
                let table = IdentifiedTable("media")
                state.table = table
                return .run { send in
                    let createTableQuery = table().create {
                        $0.column(.Media.id, primaryKey: .autoincrement)
                        $0.column(.Media.musicId)
                        $0.column(.Media.addedDate)
                        $0.column(.Media.artistName)
                        $0.column(.Media.albumName)
                        $0.column(.Media.songName)
                        $0.column(.Media.releaseDate)
                        $0.column(.Media.albumArtURL)
                        $0.column(.Media.snippetArtDataPath)
                        $0.column(.Media.artistURL)
                        $0.column(.Media.storeURL)
                        $0.column(.Media.duration)
                        $0.column(.Media.saved)
                    }
                    
                    try connection.run(createTableQuery)
                }
            }
        }
    }
}
