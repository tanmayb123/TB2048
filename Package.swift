// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NN2048",
    products: [
      .executable(
        name: "NN2048",
        targets:  ["NN2048"]
      )
    ],
    dependencies: [
      .package(url: "https://github.com/IBM-Swift/Kitura.git", from: "2.6.0"),
    ],
    targets: [
      .target(
        name: "NN2048",
        dependencies: ["Kitura"]
      )
    ]
)
