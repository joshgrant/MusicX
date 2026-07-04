import ProjectDescription

let project = Project(
    name: "MusicX",
    organizationName: "Joshua Grant",
    // French ships as a String Catalog (Resources/*.xcstrings). Tuist only
    // infers regions from .lproj folders, so declare `fr` explicitly or the
    // catalog's French never gets compiled into the app bundle.
    options: .options(defaultKnownRegions: ["en", "fr"], developmentRegion: "en"),
    packages: [
        // Pinned to the revision that was resolved from `main` so release
        // builds are reproducible.
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", .revision("8631b5fbcc5c4ae3866474d431d64da3677df216")),
        .package(path: "../../Packages/SmallCharacterModel")
    ],
    targets: [
        .target(
            name: "MusicX",
            destinations: [.iPad, .iPhone, .mac],
            product: .app,
            bundleId: "com.joshgr.MusicX",
            infoPlist: .dictionary([
                "CFBundlePackageType": "$(PRODUCT_BUNDLE_PACKAGE_TYPE)",
                "CFBundleName": "$(PRODUCT_NAME)",
                "CFBundleDisplayName": "MusicX",
                "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                "CFBundleInfoDictionaryVersion": "6.0",
                "NSHumanReadableCopyright": "Copyright © Joshua Grant. All rights reserved.",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleExecutable": "$(EXECUTABLE_NAME)",
                "UIRequiresFullScreen": "YES",
                "ITSAppUsesNonExemptEncryption": "NO",
                "UISupportedInterfaceOrientations": .array([
                    "UIInterfaceOrientationPortrait"
                ]),
                "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
                "UILaunchScreen": .dictionary([
                    "UIColorName": "systemBackgroundColor"
                ]),
                "NSAppleMusicUsageDescription": "MusicX uses Apple Music to discover new songs",
                "LSApplicationCategoryType": "public.app-category.music"
            ]),
            sources: ["Sources/**"],
            resources: [
                // song-titles.txt is only the training source for the
                // pre-trained model; the app loads song-titles_3.media.
                .glob(pattern: "Resources/**", excluding: ["Resources/song-titles.txt"])
            ],
            dependencies: [
                .package(product: "ComposableArchitecture"),
                .package(product: "SmallCharacterModel")
            ],
            settings: .settings(base: [
                "STRING_CATALOG_GENERATE_SYMBOLS": "YES",
                "ENABLE_APP_SANDBOX": "YES",
                "ENABLE_OUTGOING_NETWORK_CONNECTIONS": "YES",
                "SWIFT_VERSION": "5",
                "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
                "ENABLE_HARDENED_RUNTIME": "YES",
                "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
                "DEVELOPMENT_TEAM": "685257RUQP",
                "CURRENT_PROJECT_VERSION": "1",
                "MARKETING_VERSION": "1.0"
            ]))
    ],
    fileHeaderTemplate: .string(
    """
    // © BCE Labs, 2024. All rights reserved.
    //
    """),
    additionalFiles: [
        "Project.swift"
    ])
