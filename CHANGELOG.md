# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Device rotation support: the transition frame and zoom scale follow the new orientation.
- iOS 26 Liquid Glass styling for the default close button and page indicator (falls back on earlier versions).
- `os.Logger` based logging (subsystem `com.shima11.ImageViewer`) for image loading and presentation failures.
- `ImageSource.url(_:placeholder:)` convenience source backed by `URLSession`.
- `ImageViewerConfiguration.enableHDR` to render HDR images on capable displays (iOS 17+).
- Tapping the error view retries a failed async/URL image load.
- Unit tests for index clamping, `ImageSource.placeholder` / `.url`, and `enableHDR`.

### Changed
- `ImageViewerConfiguration.onDismiss` / `onPageChange` are now `@MainActor` closures, so updating SwiftUI state from them no longer triggers concurrency warnings.
- Multi-window safety: the cover window is presented in the caller's window scene instead of the first foreground-active scene.
- The default close button is pinned to the safe area layout guide (correct under rotation and varying safe areas).
- Async-loaded images more than two pages away are released to bound memory in large galleries.
- `ImageViewerError` now distinguishes `.indexOutOfRange(index:count:)` from `.invalidData`.

### Fixed
- The viewer could become unpresentable when no active scene was available; state is now rolled back so it can be presented again.
- Failed async image loads are no longer re-fetched in a loop.
- The image load `Task` no longer retains the controller (`[weak self]`).
- A dismiss animation interrupted by rotation no longer strands the `onDismiss` callback.
- After rotation, dismissal no longer animates to a stale source frame; it falls back to a slide-down animation.

## [0.1.0]

### Added
- Initial release: SwiftUI image viewer with zoom transitions, gesture-based
  navigation, multi-image pagination, async image loading, full UI customization,
  and accessibility (VoiceOver, Dynamic Type, Reduce Motion).

[Unreleased]: https://github.com/shima11/ImageViewer/compare/0.1.0...HEAD
[0.1.0]: https://github.com/shima11/ImageViewer/releases/tag/0.1.0
