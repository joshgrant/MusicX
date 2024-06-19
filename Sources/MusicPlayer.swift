// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import ComposableArchitecture
import MusicKit

extension ApplicationMusicPlayer: DependencyKey {
    public static var liveValue: ApplicationMusicPlayer {
        .shared
    }
}

extension DependencyValues {
    
    var musicPlayer: ApplicationMusicPlayer {
        get { self[ApplicationMusicPlayer.self] }
        set { self[ApplicationMusicPlayer.self] = newValue }
    }
}
