// © BCE Labs, 2024. All rights reserved.
//

import Foundation

struct Media: Codable, Equatable {
    var id: String
    var songName: String
    var artistName: String
    var albumName: String?
    var playCount: Int
    var trackDuration: Double
    var songUrl: URL?
    
    static func == (lhs: Media, rhs: Media) -> Bool {
        lhs.id == rhs.id
    }
}
