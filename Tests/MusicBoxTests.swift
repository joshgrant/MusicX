import ProjectDescription

let project = Project(
    name: "MusicBox",
    targets: [
        .init(
            name: "MusicBox",
            destinations: [.iPad, .iPhone, .mac],
            product: .app,
            bundleId: "com.bcelabs.MusicBox",
            infoPlist: .default,
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: []),
        .init(
            name: "MusicBoxTests",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "com.bcelabs.MusicBoxTests",
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [.target(name: "MusicBox")])
    ])
