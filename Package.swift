// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacDeck",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacDeck", targets: ["MacDeck"])
    ],
    targets: [
        .executableTarget(
            name: "MacDeck",
            dependencies: [],
            path: "Sources/MacDeck",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-load-plugin-library",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib"
                ])
            ]
        ),
        .testTarget(
            name: "MacDeckTests",
            dependencies: ["MacDeck"],
            path: "Tests/MacDeckTests",
            swiftSettings: [
                .unsafeFlags([
                    "-load-plugin-library",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib",
                    "-load-plugin-library",
                    "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib",
                    "-F",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-I",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
                    "-L",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
                ])
            ]
        )
    ]
)
