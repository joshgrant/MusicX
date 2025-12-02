// © BCE Labs, 2024. All rights reserved.
//

import OSLog
import SmallCharacterModel

public class Container {
    public let logger: Logger
    public let model: CharacterModelState
    public let musicService: MusicService
    public let appState: AppState
    
    public init(
        logger: Logger,
        model: CharacterModelState,
        musicService: MusicService,
        appState: AppState
    ) throws {
        self.logger = logger
        self.model = model
        self.musicService = musicService
        self.appState = appState
    }
}
