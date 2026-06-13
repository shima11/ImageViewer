# ``ImageViewer``

A SwiftUI image viewer with smooth zoom transitions, gesture-based navigation, and full customization.

## Overview

`ImageViewer` presents images full-screen with Photo-app-like zoom transitions
from a thumbnail, pinch and double-tap zoom, swipe-to-dismiss, and horizontal
paging for multiple images. It integrates with any async image loading library
(Nuke, Kingfisher, SDWebImage, …) through ``ImageSource``.

Attach the viewer to any view with the ``SwiftUICore/View/imageViewer(isPresented:image:sourceFrame:sourceContentMode:configuration:)`` family of modifiers:

```swift
Image(uiImage: image)
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { sourceFrame = $0 }
    .onTapGesture { isPresented = true }
    .imageViewer(isPresented: $isPresented, image: image, sourceFrame: sourceFrame)
```

The default UI (close button, page indicator, loading and error views) adopts
the iOS 26 Liquid Glass appearance and falls back automatically on iOS 17–25.

## Topics

### Image Sources

- ``ImageSource``

### Configuration

- ``ImageViewerConfiguration``
- ``ImageViewerContext``

### Default UI Components

- ``DefaultCloseButton``
- ``DefaultPageIndicator``
- ``DefaultLoadingView``
- ``DefaultErrorView``

### Retrying Failed Loads

- ``ImageViewerRetryAction``
