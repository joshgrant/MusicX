// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SQLite
import MusicKit
import ComposableArchitecture

@Reducer
public struct GenresFeature {
    
    public struct State: Equatable {
        public var table: IdentifiedTable?
        
        public init() {}
    }
    
    public enum Action {
        @CasePathable
        public enum Delegate {
            case allGenresResult([String])
        }
        
        case delegate(Delegate)
        
        // Actions
        case createTable
        case addGenre(String)
        case fetchGenres
    }
    
    @Dependency(\.connection) var connection
    
    public init() {}
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none
            case .createTable:
                let table = IdentifiedTable("genres")
                state.table = table
                return .run { send in
                    let createTableQuery = table().create {
                        $0.column(.Genres.id, primaryKey: .autoincrement)
                        $0.column(.Genres.name, unique: true)
                    }
                    try connection.run(createTableQuery)
                }
            case .addGenre(let genre):
                return .run { [table = state.table] send in
                    guard let table = table?() else {
                        XCTFail("Could not add genre column. No table.")
                        return
                    }
                    let insert = table.insert(.Genres.name <- genre)
                    try connection.run(insert)
                }
            case .fetchGenres:
                return .run { [table = state.table] send in
                    guard let table = table?() else {
                        XCTFail("Could not add genre column. No table.")
                        return
                    }
                    
                    let genres = try connection
                        .prepare(table)
                        .map {
                            try $0.get(.Genres.name)
                        }
                    await send(.delegate(.allGenresResult(genres)))
                }
            }
        }
    }
}
