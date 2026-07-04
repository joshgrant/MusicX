// © BCE Labs, 2024. All rights reserved.
//

import Foundation

enum Constants {

    enum UserDefaultsKey: String {
        case autoPlay
        case configurationId
        case hasSeenWelcome
        case hiddenGenres
    }
}

extension UserDefaults {

    /// Genres the user has hidden from Discover. Songs tagged with any of
    /// these are skipped by the discovery algorithm.
    var hiddenGenres: [String] {
        get { stringArray(forKey: Constants.UserDefaultsKey.hiddenGenres.rawValue) ?? [] }
        set { set(newValue, forKey: Constants.UserDefaultsKey.hiddenGenres.rawValue) }
    }
}
