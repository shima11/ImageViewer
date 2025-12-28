# ImageViewer

A SwiftUI image viewer with smooth zoom transitions, pinch-to-zoom, and interactive dismiss gestures. Built with UIWindow to display above sheets and modals.

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- **UIWindow-based**: Displays above sheets, modals, and other overlays
- **Zoom Transition**: Smooth animation from source image to full-screen
- **Pinch to Zoom**: Natural zoom gesture with configurable limits
- **Double-tap Zoom**: Quick zoom toggle with smart positioning
- **Interactive Dismiss**: Drag down to dismiss with visual feedback
- **Swift 6 Ready**: Full concurrency support with Sendable conformance

## Requirements

- iOS 17.0+
- Swift 6.0+
- Xcode 16.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/shima11/ImageViewer.git", from: "1.0.0")
]
```

Or add it directly in Xcode via File → Add Package Dependencies.

## Usage

### Basic Usage

```swift
import ImageViewer
import SwiftUI

struct ContentView: View {
    @State private var showViewer = false
    @State private var sourceFrame: CGRect = .zero
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .readFrame { frame in
                sourceFrame = frame
            }
            .onTapGesture {
                showViewer = true
            }
            .imageViewer(
                isPresented: $showViewer,
                image: image,
                sourceFrame: sourceFrame
            )
    }
}
```

### With Configuration

```swift
.imageViewer(
    isPresented: $showViewer,
    image: image,
    sourceFrame: sourceFrame,
    configuration: ImageViewerConfiguration(
        maxScale: 5.0,           // Maximum zoom scale
        doubleTapScale: 3.0,     // Scale on double-tap
        backgroundColor: .black,  // Background color
        dismissThreshold: 100,    // Distance to trigger dismiss
        dismissVelocityThreshold: 500  // Velocity to trigger dismiss
    )
)
```

### Using Inside a Sheet

The viewer works seamlessly inside sheets because it uses a separate UIWindow:

```swift
.sheet(isPresented: $showSheet) {
    VStack {
        Image(uiImage: image)
            .readFrame { sourceFrame = $0 }
            .onTapGesture { showViewer = true }
            .imageViewer(
                isPresented: $showViewer,
                image: image,
                sourceFrame: sourceFrame
            )
    }
}
```

## How It Works

### UIWindow Overlay

Unlike `fullScreenCover`, this library creates a separate UIWindow with a high window level (`.alert + 1`). This ensures the viewer appears above:

- Navigation bars
- Tab bars
- Sheets
- Modals
- Other overlays

### Zoom Transition

The viewer captures the source image's frame using the `readFrame` modifier and animates from that position to full-screen. On dismiss, it reverses the animation back to the source position.

### Interactive Dismiss

When not zoomed, dragging the image triggers an interactive dismiss:

- The background fades as you drag
- The image scales down toward the source position
- Release to dismiss or snap back

## Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `maxScale` | `CGFloat` | 5.0 | Maximum zoom scale |
| `doubleTapScale` | `CGFloat` | 3.0 | Scale applied on double-tap |
| `backgroundColor` | `Color` | `.black` | Background color of the viewer |
| `dismissThreshold` | `CGFloat` | 100 | Distance in points to trigger dismiss |
| `dismissVelocityThreshold` | `CGFloat` | 500 | Velocity in points/second to trigger dismiss |

## License

MIT License. See [LICENSE](LICENSE) for details.
