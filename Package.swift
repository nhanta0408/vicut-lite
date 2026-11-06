// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "VicutLite",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "VicutLite", targets: ["VicutLite"]),
    .library(name: "VicutCore", targets: ["VicutCore"])
  ],
  targets: [
    .target(name: "VicutCore"),
    .executableTarget(name: "VicutLite", dependencies: ["VicutCore"]),
    .testTarget(
      name: "VicutCoreTests",
      dependencies: ["VicutCore"],
      resources: [.copy("Fixtures")]
    )
  ]
)
