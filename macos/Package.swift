// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DeepSeekPriceClock",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "DeepSeekPriceClock", targets: ["DeepSeekPriceClock"])],
  targets: [
    .target(name: "PriceClockCore"),
    .executableTarget(name: "DeepSeekPriceClock", dependencies: ["PriceClockCore"]),
    .testTarget(
      name: "PriceClockCoreTests",
      dependencies: ["PriceClockCore"],
      resources: [.copy("Fixtures")]
    ),
  ]
)
