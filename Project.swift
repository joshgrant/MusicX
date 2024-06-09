import ProjectDescription

let project = Project(
    name: "MusicBox",
    organizationName: "BCE Labs",
    packages: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", .branch("main"))
    ],
    targets: [
        .init(
            name: "MusicBox",
            destinations: [.iPad, .iPhone, .mac],
            product: .app,
            bundleId: "com.bcelabs.MusicBox",
            infoPlist: .file(path: "Info.plist"),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                .package(product: "ComposableArchitecture")
            ],
            settings: .settings(configurations: [
                .debug(name: "MusicBox.xcconfig")
            ])),
        .init(
            name: "MusicBoxTests",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "com.bcelabs.MusicBoxTests",
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: "MusicBox")])
    ],
    fileHeaderTemplate: .string(
    """
    // © BCE Labs, 2024. All rights reserved.
    //
    """),
    additionalFiles: [
        "Project.swift",
        "MusicBox.xcconfig"
    ])
