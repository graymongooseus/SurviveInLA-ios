// swift-tools-version: 6.0
import PackageDescription

// Fast core tests on macOS. The shipping iOS app and artwork tests stay in Xcode.
let package = Package(
    name: "SurviveInLA",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "SurviveInLA",
            path: "SurviveInLA",
            exclude: ["App", "UI", "Resources/Assets.xcassets", "Resources/PrivacyInfo.xcprivacy", "SurviveInLA.entitlements"],
            sources: ["Domain", "Engine", "Store"],
            resources: [.copy("Resources/Content")]
        ),
        .testTarget(name: "SurviveInLATests", dependencies: ["SurviveInLA"], path: "SurviveInLATests")
    ],
    swiftLanguageModes: [.v6]
)
