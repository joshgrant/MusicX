import ProjectDescription

let project = Project(
    name: "MusicX",
    organizationName: "BCE Labs",
    packages: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", .branch("main")),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", .branch("master")),
        .package(url: "https://github.com/joshgrant/SmallCharacterModel.git", .branch("main"))
    ],
    targets: [
        .target(
            name: "MusicX",
            destinations: [.iPad, .iPhone, .mac],
            product: .app,
            bundleId: "com.bcelabs.MusicX",
            infoPlist: .file(path: "Info.plist"),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                .package(product: "ComposableArchitecture"),
                .package(product: "SmallCharacterModel"),
                .package(product: "SQLite")
            ],
            settings: .settings(configurations: [
                .debug(name: "MusicX.xcconfig")
            ])),
        .target(
            name: "MusicXTests",
            destinations: [.mac, .iPad, .iPhone],
            product: .unitTests,
            bundleId: "com.bcelabs.MusicXTests",
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "MusicX")
            ])
    ],
    fileHeaderTemplate: .string(
    """
    // © BCE Labs, 2024. All rights reserved.
    //
    """),
    additionalFiles: [
        "Project.swift",
        "MusicX.xcconfig"
    ])
