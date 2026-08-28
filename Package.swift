// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let homebrewPrefix = ["/opt/homebrew", "/usr/local"].first { prefix in
    [
        "\(prefix)/opt/libxmlsec1/include/xmlsec1",
        "\(prefix)/opt/libxml2/include/libxml2",
        "\(prefix)/opt/openssl@3/include"
    ].allSatisfy(FileManager.default.fileExists(atPath:))
}

// Homebrew's xmlsec1.pc contains compiler definitions that SwiftPM rejects.
// Linux still needs pkg-config to discover distribution-specific include paths.
#if os(macOS)
let xmlSecPkgConfig: String? = nil
#else
let xmlSecPkgConfig: String? = "xmlsec1"
#endif

let xmlSecBridgeCSettings: [CSetting] = [
    // Keep the public xmlsec headers in sync with the Homebrew build without
    // importing arbitrary compiler definitions from xmlsec1.pc. SwiftPM only
    // permits include/framework paths in pkg-config Cflags and otherwise emits
    // a "prohibited flag(s)" warning.
    .define("__XMLSEC_FUNCTION__", to: "__func__", .when(platforms: [.macOS])),
    .define("XMLSEC_NO_FTP", to: "1", .when(platforms: [.macOS])),
    .define("XMLSEC_NO_HTTP", to: "1", .when(platforms: [.macOS])),
    .define("XMLSEC_NO_MD5", to: "1", .when(platforms: [.macOS])),
    .define("XMLSEC_NO_RIPEMD160", to: "1", .when(platforms: [.macOS])),
    .define("XMLSEC_NO_MLDSA", to: "1", .when(platforms: [.macOS])),
    .define("XMLSEC_NO_MLKEM", to: "1", .when(platforms: [.macOS])),
    .define("XMLSEC_NO_SLHDSA", to: "1", .when(platforms: [.macOS])),
    .define("XMLSEC_NO_GOST", to: "1", .when(platforms: [.macOS])),
    .define("XMLSEC_NO_GOST2012", to: "1", .when(platforms: [.macOS])),
    .define("XMLSEC_NO_CRYPTO_DYNAMIC_LOADING", to: "1", .when(platforms: [.macOS])),
    .define("XMLSEC_CRYPTO_OPENSSL", to: "1")
] + (homebrewPrefix.map { prefix in
    [
        .unsafeFlags([
            "-I\(prefix)/opt/libxmlsec1/include/xmlsec1",
            "-I\(prefix)/opt/libxml2/include/libxml2",
            "-I\(prefix)/opt/openssl@3/include"
        ], .when(platforms: [.macOS]))
    ]
} ?? [])

let xmlSecBridgeLinkerSettings: [LinkerSetting] = [
    .linkedLibrary("xmlsec1-openssl"),
    .linkedLibrary("xmlsec1"),
    .linkedLibrary("ssl"),
    .linkedLibrary("crypto"),
    .linkedLibrary("xslt"),
    .linkedLibrary("xml2")
] + (homebrewPrefix.map { prefix in
    [
        .unsafeFlags([
            "-L\(prefix)/opt/libxmlsec1/lib",
            "-L\(prefix)/opt/libxml2/lib",
            "-L\(prefix)/opt/openssl@3/lib",
            "-Xlinker", "-rpath",
            "-Xlinker", "\(prefix)/opt/libxmlsec1/lib",
            "-Xlinker", "-rpath",
            "-Xlinker", "\(prefix)/opt/libxml2/lib"
        ], .when(platforms: [.macOS]))
    ]
} ?? [])

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
            pkgConfig: xmlSecPkgConfig,
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
