// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EaselApp",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "EaselApp",
            targets: ["EaselApp"]
        ),
    ],
    dependencies: [
        // Core dependencies for AR and AI
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.19.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.1"),
    ],
    targets: [
        .target(
            name: "EaselApp",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                "KeychainAccess",
                "Alamofire"
            ]
        ),
        .testTarget(
            name: "EaselAppTests",
            dependencies: ["EaselApp"]
        ),
    ]
)