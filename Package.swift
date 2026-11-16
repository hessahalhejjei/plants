// swift-tools-version: 5.9
import PackageDescription

// The app is built with Planto.xcodeproj. This small package lets its shared,
// Foundation-only date rules run as real Swift tests on macOS or Linux.
let package = Package(
    name: "PlantoCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "PlantoCore", targets: ["Planto"])],
    targets: [
        .target(name: "Planto", path: "Planto/Models"),
        .testTarget(
            name: "PlantoCoreTests",
            dependencies: ["Planto"],
            path: "PlantoTests",
            exclude: ["PlantStoreTests.swift"],
            sources: ["PlantReminderTests.swift", "NotificationScheduleTests.swift"]
        )
    ]
)
