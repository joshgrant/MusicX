import ProjectDescription

let project = Project(
    name: "MusicX",
    organizationName: "BCE Labs",
    packages: [
//        .package(url: "https://github.com/joshgrant/SmallCharacterModel.git", from: "3.0.3")
        .package(path: "../../Packages/SmallCharacterModel")
    ],
    targets: [
        .target(
            name: "MusicX",
            destinations: [.iPad, .iPhone, .mac],
            product: .app,
            bundleId: "com.bcelabs.MusicX",
            infoPlist: .file(path: "Info.plist"),
            sources: ["Sources/MusicX/**"],
            resources: ["Resources/**"],
            dependencies: [
                .target(name: "MusicXCore")
            ],
            settings: .settings(configurations: [
                .debug(name: "MusicX.xcconfig")
            ])),
        .target(
            name: "MusicXCore",
            destinations: [.mac, .iPhone, .iPad],
            product: .framework,
            bundleId: "com.bcelabs.MusicXCore",
            sources: ["Sources/Core/**"],
            dependencies: [
                .package(product: "SmallCharacterModel"),
            ]),
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
