// swift-tools-version: 5.9
import PackageDescription

// The app is built with Planto.xcodeproj. This package tests its shared models,
// view models, and JSON storage on macOS or Linux.
let package = Package(
    name: "PlantoCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "PlantoCore", targets: ["Planto"])],
    // Only the Linux test package needs OpenCombine; the iOS app uses Apple's Combine.
    dependencies: [
        .package(url: "https://github.com/OpenCombine/OpenCombine.git", exact: "0.14.0")
    ],
    targets: [
        .target(
            name: "Planto",
            dependencies: [
                .product(name: "OpenCombine", package: "OpenCombine", condition: .when(platforms: [.linux]))
            ],
            path: "Planto",
            exclude: ["Views", "PlantoApp.swift", "Assets.xcassets", "PrivacyInfo.xcprivacy", "Services/NotificationService.swift"],
            sources: ["Models", "ViewModels", "Services/JSONPlantStorage.swift"]
        ),
        .testTarget(
            name: "PlantoCoreTests",
            dependencies: ["Planto"],
            path: "PlantoTests",
            sources: ["PlantReminderTests.swift", "NotificationScheduleTests.swift", "PlantsViewModelTests.swift", "ScreenViewModelTests.swift"]
        )
    ]
)
