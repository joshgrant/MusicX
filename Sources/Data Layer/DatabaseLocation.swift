// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import Dependencies

struct DatabaseLocation: DependencyKey {
    var location: String
    
    static var liveValue: DatabaseLocation {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("database.sql")
        return .init(location: .onDisk(fileURL.path()))
    }
    
    static var testValue: DatabaseLocation {
        .init(location: .inMemory)
    }
}

extension DependencyValues {
    
    var databaseLocation: DatabaseLocation {
        get { self[DatabaseLocation.self] }
        set { self[DatabaseLocation.self] = newValue }
    }
}
