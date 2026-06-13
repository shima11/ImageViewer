// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "ImageViewer",
  platforms: [
    .iOS(.v17)
  ],
  products: [
    .library(
      name: "ImageViewer",
      targets: ["ImageViewer"]
    )
  ],
  targets: [
    .target(
      name: "ImageViewer"
    ),
    .testTarget(
      name: "ImageViewerTests",
      dependencies: ["ImageViewer"]
    ),
  ]
)
