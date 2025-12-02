// © BCE Labs, 2024. All rights reserved.
//

import Observation

@Observable
public class AppState: Codable {
    
    public struct Settings: Codable {
        
        public enum SearchType: Codable {
            case song
            case album
            case artist
        }
        
        public enum RandomMode: Codable {
            case probable
            case chaotic
        }
        
        var searchType: SearchType
        var randomMode: RandomMode
        var autoPlay: Bool
        var includeTopResults: Bool
        
        public init(
            searchType: SearchType,
            randomMode: RandomMode,
            autoPlay: Bool,
            includeTopResults: Bool
        ) {
            self.searchType = searchType
            self.randomMode = randomMode
            self.autoPlay = autoPlay
            self.includeTopResults = includeTopResults
        }
    }
    
    public class UIState: Codable {
        var isSearching: Bool
        
        public init(isSearching: Bool) {
            self.isSearching = isSearching
        }
    }
    
    public var settings: Settings
    public var history: [MusicXSong]
    public var bookmarks: Set<MusicXSong>
    public var uiState: UIState
    
    public init(
        settings: Settings,
        history: [MusicXSong],
        bookmarks: Set<MusicXSong>,
        uiState: UIState
    ) {
        self.settings = settings
        self.history = history
        self.bookmarks = bookmarks
        self.uiState = uiState
    }
}
