// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import MusicKit

public enum MusicPlaybackStatus: String, CustomStringConvertible, CustomLocalizedStringResourceConvertible {
    
    case stopped
    case playing
    case paused
    case interrupted
    case seekingForward
    case seekingBackward
    
    public var description: String {
        rawValue
    }
    
    public var localizedStringResource: LocalizedStringResource {
        .init(stringLiteral: rawValue)
    }
    
    public init(
        applicationPlaybackStatus: ApplicationMusicPlayer.PlaybackStatus
    ) {
        switch applicationPlaybackStatus {
        case .stopped: self = .stopped
        case .playing: self = .playing
        case .paused: self = .paused
        case .interrupted: self = .interrupted
        case .seekingForward: self = .seekingForward
        case .seekingBackward: self = .seekingBackward
        @unknown default:
            self = .stopped
        }
    }
}
