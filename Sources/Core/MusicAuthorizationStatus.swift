// © BCE Labs, 2024. All rights reserved.
//

import MusicKit

public enum MusicAuthorizationStatus {
    case notDetermined
    case denied
    case restricted
    case authorized
    
    public init(
        musicAuthorizationStatus: MusicAuthorization.Status
    ) {
        switch musicAuthorizationStatus {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .authorized: self = .authorized
        default:
            self = .notDetermined
        }
    }
}
