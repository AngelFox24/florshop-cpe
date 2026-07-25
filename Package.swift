// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let homebrewPrefix = ["/opt/homebrew", "/usr/local"].first { prefix in
    FileManager.default.fileExists(atPath: "\(prefix)/opt/libxml2/include/libxml2")
}

let xmlSecBridgeCSettings: [CSetting] = [
    .define("XMLSEC_CRYPTO_OPENSSL")
] + (homebrewPrefix.map { prefix in
    [
        // xmlsec1's Homebrew pkg-config file does not include libxml2's
        // headers. Without this, Xcode mixes macOS libxml2 headers with
        // Homebrew libxmlsec/libxml2 at runtime.
        .unsafeFlags(["-I\(prefix)/opt/libxml2/include/libxml2"], .when(platforms: [.macOS]))
    ]
} ?? [])

let xmlSecBridgeLinkerSettings: [LinkerSetting] = homebrewPrefix.map { prefix in
    [
        .unsafeFlags([
            "-L\(prefix)/opt/libxml2/lib",
            "-Xlinker", "-rpath",
            "-Xlinker", "\(prefix)/opt/libxml2/lib"
        ], .when(platforms: [.macOS]))
    ]
} ?? []

let package = Package(
    name: "FlorShopCPE",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FlorShopCPE",
            targets: ["FlorShopCPE"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FlorShopCPE",
            dependencies: [
                .target(name: "XMLSecBridge", condition: .when(platforms: [.linux, .macOS])),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .systemLibrary(
            name: "CXMLSec",
            pkgConfig: "xmlsec1",
            providers: [
                .brew(["libxmlsec1"]),
                .apt(["libxmlsec1-dev"])
            ]
        ),
        .target(
            name: "XMLSecBridge",
            dependencies: ["CXMLSec"],
            cSettings: xmlSecBridgeCSettings,
            linkerSettings: xmlSecBridgeLinkerSettings
        ),
        .testTarget(
            name: "FlorShopCPETests",
            dependencies: ["FlorShopCPE"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
