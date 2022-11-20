// swift-tools-version:5.6
import PackageDescription
let package = Package(
    name: "AppExaminerViewer",
    platforms: [.macOS(.v11), .iOS(.v14)],
    products: [
        .executable(name: "AppExaminerViewerApp", targets: ["AppExaminerViewerApp"]),
        .library(
            name: "AppExaminerViewerCore",
            targets: ["AppExaminerViewerCore"]
        ),
    ],
    dependencies: [
        .package(name: "Tokamak", url: "https://github.com/TokamakUI/Tokamak", from: "0.11.1"),
        .package(name: "WebAPIKit", url: "https://github.com/swiftwasm/WebAPIKit", branch: "main"),
        .package(
            url: "https://github.com/Flight-School/AnyCodable",
            from: "0.6.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "AppExaminerViewerApp",
            dependencies: [
                .target(name: "AppExaminerViewerCore")
            ]),
        .target(
            name: "AppExaminerViewerCore",
            dependencies: [
                .product(name: "TokamakDOM", package: "Tokamak", condition: .when(platforms: [.wasi])),
                .product(name: "WebSockets", package: "WebAPIKit", condition: .when(platforms: [.wasi])),
                .product(name: "AnyCodable", package: "AnyCodable"),
            ]),
        .testTarget(
            name: "AppExaminerViewerAppTests",
            dependencies: ["AppExaminerViewerApp"]),
    ]
)
