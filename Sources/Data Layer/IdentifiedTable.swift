// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SQLite

public struct IdentifiedTable: Identifiable {
    
    public var id: String
    public var table: Table
    
    public init(_ name: String) {
        self.id = name
        self.table = Table(name)
    }
    
    public func callAsFunction() -> Table {
        table
    }
}

extension IdentifiedTable: Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
