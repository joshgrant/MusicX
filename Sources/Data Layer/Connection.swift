// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import SQLite

extension Connection: DependencyKey {
    
    public static var liveValue: Connection {
        do {
            return try Connection(.uri("/Users/me/Desktop/test.db"))
        } catch {
            fatalError("Failed to create the database: \(error)")
        }
    }
    
    public static var testValue: Connection {
        do {
            return try Connection(.inMemory)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

extension DependencyValues {
    
    var connection: Connection {
        get { self[Connection.self] }
        set { self[Connection.self] = newValue }
    }
}
