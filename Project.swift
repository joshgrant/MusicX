import ProjectDescription

let project = Project(
    name: "MusicX",
    organizationName: "Joshua Grant",
    packages: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", .branch("main")),
        .package(url: "https://github.com/joshgrant/SmallCharacterModel.git", .branch("main"))
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
                "CFBundleDisplayName": "Morning",
                "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                "CFBundleInfoDictionaryVersion": "6.0",
                "NSHumanReadableCopyright": "Copyright © Joshua Grant. All rights reserved.",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleExecutable": "$(EXECUTABLE_NAME)",
                "UISupportedInterfaceOrientations": .array([
                    "UIInterfaceOrientationPortrait"
                ]),
                "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
                "UILaunchScreen": .dictionary([
                    "UIColorName": "systemBackgroundColor"
                ]),
                "NSAppleMusicUsageDescription": "MusicX uses Apple Music to discover new songs"
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
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
