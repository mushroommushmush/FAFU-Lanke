// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "CampusCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "CampusCore", targets: ["CampusCore"])],
    dependencies: [.package(url: "https://github.com/scinfu/SwiftSoup.git", exact: "2.7.7")],
    targets: [
        .target(name: "CampusCore", dependencies: [.product(name: "SwiftSoup", package: "SwiftSoup")]),
        .testTarget(name: "CampusCoreTests", dependencies: ["CampusCore"], resources: [.process("Fixtures")])
    ]
)
