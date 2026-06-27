// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MealMemory",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MealMemory", targets: ["MealMemory"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/supabase/supabase-swift.git",
            from: "2.0.0"
        )
    ],
    targets: [
        .target(
            name: "MealMemory",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Sources/MealMemory"
        ),
        .testTarget(
            name: "MealMemoryTests",
            dependencies: ["MealMemory"],
            path: "Tests"
        )
    ]
)
