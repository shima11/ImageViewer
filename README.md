# ImageViewer

A SwiftUI image viewer with smooth zoom transitions, gesture-based navigation, and full customization support.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- **Smooth Transitions** - Photo app-like zoom transitions from thumbnail to fullscreen
- **Gesture Support** - Pinch to zoom, double-tap zoom, swipe to dismiss, page navigation
- **Multiple Images** - Horizontal swipe pagination with UIPageViewController
- **Async Loading** - Seamless integration with Nuke, Kingfisher, SDWebImage, or any async loader
- **Full Customization** - Custom overlay, close button, page indicator, loading/error views
- **Accessibility** - VoiceOver, Dynamic Type, and Reduce Motion support

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

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Quick Start

### Single Image

```swift
import ImageViewer

struct ContentView: View {
    @State private var isPresented = false
    @State private var sourceFrame: CGRect = .zero
    let image = UIImage(named: "sample")!

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 200, height: 150)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sourceFrame = $0 }
            .onTapGesture { isPresented = true }
            .imageViewer(
                isPresented: $isPresented,
                image: image,
                sourceFrame: sourceFrame
            )
    }
}
```

### Multiple Images (Gallery)

```swift
struct GalleryView: View {
    @State private var isPresented = false
    @State private var selectedIndex = 0
    @State private var sourceFrames: [CGRect] = Array(repeating: .zero, count: 6)
    let images: [UIImage] = [...]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .opacity(isPresented && selectedIndex == index ? 0 : 1)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sourceFrames[index] = $0 }
                    .onTapGesture {
                        selectedIndex = index
                        isPresented = true
                    }
            }
        }
        .imageViewer(
            isPresented: $isPresented,
            images: images,
            initialIndex: selectedIndex,
            sourceFrames: sourceFrames,
            sourceContentMode: .fill,
            configuration: ImageViewerConfiguration(
                onPageChange: { selectedIndex = $0 }
            )
        )
    }
}
```

### Remote Images with Image Loading Libraries

ImageViewer is designed to work with your preferred image loading library. Use the `.async` source to integrate with Nuke, Kingfisher, SDWebImage, or any async image loader.

#### With Nuke

```swift
import Nuke

.imageViewer(
    isPresented: $isPresented,
    sources: urls.map { url in
        .async({
            try await ImagePipeline.shared.image(for: url)
        }, placeholder: thumbnailCache[url])
    }
)
```

#### With Kingfisher

```swift
import Kingfisher

.imageViewer(
    isPresented: $isPresented,
    sources: urls.map { url in
        .async({
            try await withCheckedThrowingContinuation { continuation in
                KingfisherManager.shared.retrieveImage(with: url) { result in
                    continuation.resume(with: result.map { $0.image })
                }
            }
        }, placeholder: nil)
    }
)
```

#### With SDWebImage

```swift
import SDWebImage

.imageViewer(
    isPresented: $isPresented,
    sources: urls.map { url in
        .async({
            try await withCheckedThrowingContinuation { continuation in
                SDWebImageManager.shared.loadImage(with: url, progress: nil) { image, _, error, _, _, _ in
                    if let image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: error ?? URLError(.badServerResponse))
                    }
                }
            }
        }, placeholder: SDImageCache.shared.imageFromCache(forKey: url.absoluteString))
    }
)
```

#### Simple URLSession (no caching)

```swift
.imageViewer(
    isPresented: $isPresented,
    sources: urls.map { url in
        .async({
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            return image
        }, placeholder: nil)
    }
)
```

## Customization

### Custom Overlay

```swift
.imageViewer(
    isPresented: $isPresented,
    images: images,
    initialIndex: selectedIndex
) { context in
    VStack {
        Spacer()
        Text("Image \(context.currentIndex + 1) of \(context.totalCount)")
            .foregroundStyle(.white)
            .padding()
    }
}
```

### Full Customization

```swift
.imageViewer(
    isPresented: $isPresented,
    sources: imageSources,
    initialIndex: 0,
    sourceFrames: frames,
    sourceContentMode: .fill,
    configuration: ImageViewerConfiguration(
        maxScale: 10.0,
        doubleTapScale: 3.0,
        backgroundColor: .black,
        dismissThreshold: 100,
        onPageChange: { print("Page: \($0)") }
    ),
    overlay: { context in CustomOverlay(context: context) },
    closeButton: { dismiss in CustomCloseButton(action: dismiss) },
    pageIndicator: { current, total in CustomPageIndicator(current: current, total: total) },
    loadingContent: { CustomLoadingView() },
    errorContent: { error in CustomErrorView(error: error) }
)
```

## Configuration Options

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `maxScale` | `CGFloat` | `5.0` | Maximum zoom scale |
| `doubleTapScale` | `CGFloat` | `3.0` | Zoom scale on double-tap |
| `backgroundColor` | `Color` | `.black` | Viewer background color |
| `transitionCornerRadius` | `CGFloat` | `8` | Corner radius during transition |
| `dismissThreshold` | `CGFloat` | `100` | Vertical distance to trigger dismiss |
| `dismissVelocityThreshold` | `CGFloat` | `500` | Velocity threshold for dismiss |
| `onDismiss` | `(() -> Void)?` | `nil` | Called when viewer is dismissed |
| `onPageChange` | `((Int) -> Void)?` | `nil` | Called when page changes |

## Image Sources

```swift
// Pre-loaded UIImage (most common)
ImageSource.image(uiImage)

// Async loader with optional placeholder
// Use this to integrate with your image loading library
ImageSource.async({ try await fetchImage() }, placeholder: thumbnailImage)
```

## Gestures

| Gesture | Action |
|---------|--------|
| Single tap | Toggle overlay visibility |
| Double-tap | Toggle zoom (1x ↔ 3x) |
| Pinch | Zoom in/out |
| Drag (when zoomed) | Pan image |
| Vertical swipe | Dismiss viewer |
| Horizontal swipe | Navigate pages (multi-image) |
| Tap background | Dismiss viewer |

## Accessibility

- VoiceOver labels and hints
- Magic Tap to dismiss
- Escape action support
- Reduce Motion support (simplified animations)

## License

MIT License. See [LICENSE](LICENSE) for details.
