import SwiftUI
import UIKit

// MARK: - Public API

extension View {

  // MARK: - Unified Image Viewer

  /// Presents a full-screen image viewer with optional swipe navigation for multiple images.
  ///
  /// This is the primary API for displaying images. It supports both single and multiple images,
  /// with zoom, pan, and interactive dismiss gestures.
  ///
  /// - Parameters:
  ///   - isPresented: A binding to whether the image viewer is presented.
  ///   - sources: The array of image sources to display.
  ///   - initialIndex: The index of the image to display initially. Defaults to 0.
  ///   - sourceFrames: Optional array of source frames for zoom transitions.
  ///   - configuration: Optional configuration for customizing the viewer behavior.
  ///   - overlay: Optional overlay content. Receives current page index.
  ///
  /// - Returns: A view that presents the image viewer when `isPresented` is true.
  ///
  /// Example (Multiple Images):
  /// ```swift
  /// .imageViewer(
  ///     isPresented: $showViewer,
  ///     sources: images.map { .image($0) },
  ///     initialIndex: selectedIndex,
  ///     sourceFrames: frames
  /// ) { currentIndex in
  ///     Text(captions[currentIndex])
  /// }
  /// ```
  public func imageViewer<Overlay: View>(
    isPresented: Binding<Bool>,
    sources: [ImageSource],
    initialIndex: Int = 0,
    sourceFrames: [CGRect]? = nil,
    configuration: ImageViewerConfiguration = .default,
    @ViewBuilder overlay: @escaping (Int) -> Overlay
  ) -> some View {
    modifier(
      ImageViewerModifier(
        isPresented: isPresented,
        sources: sources,
        initialIndex: initialIndex,
        sourceFrames: sourceFrames,
        configuration: configuration,
        overlay: overlay
      )
    )
  }

  /// Presents a full-screen image viewer with optional swipe navigation for multiple images.
  ///
  /// - Parameters:
  ///   - isPresented: A binding to whether the image viewer is presented.
  ///   - sources: The array of image sources to display.
  ///   - initialIndex: The index of the image to display initially. Defaults to 0.
  ///   - sourceFrames: Optional array of source frames for zoom transitions.
  ///   - configuration: Optional configuration for customizing the viewer behavior.
  ///
  /// - Returns: A view that presents the image viewer when `isPresented` is true.
  public func imageViewer(
    isPresented: Binding<Bool>,
    sources: [ImageSource],
    initialIndex: Int = 0,
    sourceFrames: [CGRect]? = nil,
    configuration: ImageViewerConfiguration = .default
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      sources: sources,
      initialIndex: initialIndex,
      sourceFrames: sourceFrames,
      configuration: configuration,
      overlay: { _ in EmptyView() }
    )
  }

  // MARK: - Single Image Convenience

  /// Presents a full-screen image viewer for a single image.
  ///
  /// - Parameters:
  ///   - isPresented: A binding to whether the image viewer is presented.
  ///   - source: The image source (UIImage, URL, or async loader).
  ///   - sourceFrame: The frame of the source image in global coordinates.
  ///   - configuration: Optional configuration for customizing the viewer behavior.
  ///   - overlay: Optional overlay content displayed on top of the image.
  ///
  /// - Returns: A view that presents the image viewer when `isPresented` is true.
  public func imageViewer<Overlay: View>(
    isPresented: Binding<Bool>,
    source: ImageSource,
    sourceFrame: CGRect? = nil,
    configuration: ImageViewerConfiguration = .default,
    @ViewBuilder overlay: @escaping () -> Overlay
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      sources: [source],
      initialIndex: 0,
      sourceFrames: sourceFrame.map { [$0] },
      configuration: configuration,
      overlay: { _ in overlay() }
    )
  }

  /// Presents a full-screen image viewer for a single image.
  ///
  /// - Parameters:
  ///   - isPresented: A binding to whether the image viewer is presented.
  ///   - source: The image source (UIImage, URL, or async loader).
  ///   - sourceFrame: The frame of the source image in global coordinates.
  ///   - configuration: Optional configuration for customizing the viewer behavior.
  ///
  /// - Returns: A view that presents the image viewer when `isPresented` is true.
  public func imageViewer(
    isPresented: Binding<Bool>,
    source: ImageSource,
    sourceFrame: CGRect? = nil,
    configuration: ImageViewerConfiguration = .default
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      sources: [source],
      initialIndex: 0,
      sourceFrames: sourceFrame.map { [$0] },
      configuration: configuration
    )
  }

  // MARK: - UIImage Convenience

  /// Presents a full-screen image viewer for a single UIImage.
  ///
  /// Example:
  /// ```swift
  /// @State private var showViewer = false
  /// @State private var sourceFrame: CGRect = .zero
  ///
  /// Image(uiImage: image)
  ///     .readFrame { sourceFrame = $0 }
  ///     .onTapGesture { showViewer = true }
  ///     .imageViewer(
  ///         isPresented: $showViewer,
  ///         image: image,
  ///         sourceFrame: sourceFrame
  ///     )
  /// ```
  public func imageViewer(
    isPresented: Binding<Bool>,
    image: UIImage,
    sourceFrame: CGRect? = nil,
    configuration: ImageViewerConfiguration = .default
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      source: .image(image),
      sourceFrame: sourceFrame,
      configuration: configuration
    )
  }

  /// Presents a full-screen image viewer for multiple UIImages.
  ///
  /// Example:
  /// ```swift
  /// @State private var showViewer = false
  /// @State private var selectedIndex = 0
  ///
  /// LazyVGrid(columns: columns) {
  ///     ForEach(Array(images.enumerated()), id: \.offset) { index, image in
  ///         Image(uiImage: image)
  ///             .onTapGesture {
  ///                 selectedIndex = index
  ///                 showViewer = true
  ///             }
  ///     }
  /// }
  /// .imageViewer(
  ///     isPresented: $showViewer,
  ///     images: images,
  ///     initialIndex: selectedIndex
  /// )
  /// ```
  public func imageViewer(
    isPresented: Binding<Bool>,
    images: [UIImage],
    initialIndex: Int = 0,
    sourceFrames: [CGRect]? = nil,
    configuration: ImageViewerConfiguration = .default
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      sources: images.map { .image($0) },
      initialIndex: initialIndex,
      sourceFrames: sourceFrames,
      configuration: configuration
    )
  }

  /// Presents a full-screen image viewer for multiple UIImages with custom overlay.
  ///
  /// Example:
  /// ```swift
  /// .imageViewer(
  ///     isPresented: $showViewer,
  ///     images: images,
  ///     initialIndex: selectedIndex
  /// ) { currentIndex in
  ///     VStack {
  ///         Spacer()
  ///         Text(captions[currentIndex])
  ///             .foregroundStyle(.white)
  ///     }
  /// }
  /// ```
  public func imageViewer<Overlay: View>(
    isPresented: Binding<Bool>,
    images: [UIImage],
    initialIndex: Int = 0,
    sourceFrames: [CGRect]? = nil,
    configuration: ImageViewerConfiguration = .default,
    @ViewBuilder overlay: @escaping (Int) -> Overlay
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      sources: images.map { .image($0) },
      initialIndex: initialIndex,
      sourceFrames: sourceFrames,
      configuration: configuration,
      overlay: overlay
    )
  }
}

// MARK: - Image Source

/// Represents a source for loading images in the viewer.
public enum ImageSource: Sendable {
  /// A UIImage instance.
  case image(UIImage)

  /// A URL to load the image from, with an optional placeholder.
  case url(URL, placeholder: UIImage? = nil)

  /// An async closure that returns an image.
  case async(@Sendable () async throws -> UIImage, placeholder: UIImage? = nil)

  /// Returns the placeholder image if available.
  var placeholder: UIImage? {
    switch self {
    case .image:
      return nil
    case .url(_, let placeholder):
      return placeholder
    case .async(_, let placeholder):
      return placeholder
    }
  }
}

// MARK: - Close Button Configuration

/// Position of the close button.
public enum CloseButtonPosition: Sendable {
  case topLeading
  case topTrailing
}

/// Configuration for the close button appearance.
public struct CloseButtonConfiguration: Sendable {
  /// Whether to show the close button. Default is true.
  public var isVisible: Bool

  /// Position of the close button. Default is `.topTrailing`.
  public var position: CloseButtonPosition

  /// Creates a new close button configuration.
  public init(
    isVisible: Bool = true,
    position: CloseButtonPosition = .topTrailing
  ) {
    self.isVisible = isVisible
    self.position = position
  }

  /// Default configuration.
  public static let `default` = CloseButtonConfiguration()

  /// Hidden close button.
  public static let hidden = CloseButtonConfiguration(isVisible: false)
}

// MARK: - Page Indicator Configuration

/// Style of the page indicator.
public enum PageIndicatorStyle: Sendable {
  /// Dot indicators at the bottom.
  case dots
  /// Text showing "1 / 5" format.
  case text
  /// No page indicator.
  case none
}

/// Configuration for the page indicator appearance.
public struct PageIndicatorConfiguration: Sendable {
  /// Style of the page indicator. Default is `.dots`.
  public var style: PageIndicatorStyle

  /// Tint color for the current page indicator. Default is white.
  public var currentPageColor: Color

  /// Tint color for other page indicators. Default is white with 50% opacity.
  public var pageColor: Color

  /// Creates a new page indicator configuration.
  public init(
    style: PageIndicatorStyle = .dots,
    currentPageColor: Color = .white,
    pageColor: Color = .white.opacity(0.5)
  ) {
    self.style = style
    self.currentPageColor = currentPageColor
    self.pageColor = pageColor
  }

  /// Default configuration with dots.
  public static let `default` = PageIndicatorConfiguration()

  /// Hidden page indicator.
  public static let hidden = PageIndicatorConfiguration(style: .none)
}

// MARK: - Configuration

/// Configuration options for the image viewer.
public struct ImageViewerConfiguration: Sendable {
  // MARK: - Zoom Settings

  /// The maximum zoom scale. Default is 5.0.
  public var maxScale: CGFloat

  /// The zoom scale applied on double-tap. Default is 3.0.
  public var doubleTapScale: CGFloat

  // MARK: - Appearance

  /// The background color of the viewer. Default is black.
  public var backgroundColor: Color

  /// Corner radius during transition animation. Default is 8.
  public var transitionCornerRadius: CGFloat

  // MARK: - Dismiss Gesture

  /// The vertical distance required to dismiss the viewer. Default is 100 points.
  public var dismissThreshold: CGFloat

  /// The velocity threshold for dismissing. Default is 500 points/second.
  public var dismissVelocityThreshold: CGFloat

  // MARK: - UI Components

  /// Configuration for the close button.
  public var closeButton: CloseButtonConfiguration

  /// Configuration for the page indicator (multiple images only).
  public var pageIndicator: PageIndicatorConfiguration

  // MARK: - Callbacks

  /// Called when the viewer is dismissed.
  public var onDismiss: (@Sendable () -> Void)?

  /// Called when the current page changes (multiple images only).
  public var onPageChange: (@Sendable (Int) -> Void)?

  // MARK: - Init

  /// Creates a new configuration with the specified values.
  public init(
    maxScale: CGFloat = 5.0,
    doubleTapScale: CGFloat = 3.0,
    backgroundColor: Color = .black,
    transitionCornerRadius: CGFloat = 8,
    dismissThreshold: CGFloat = 100,
    dismissVelocityThreshold: CGFloat = 500,
    closeButton: CloseButtonConfiguration = .default,
    pageIndicator: PageIndicatorConfiguration = .default,
    onDismiss: (@Sendable () -> Void)? = nil,
    onPageChange: (@Sendable (Int) -> Void)? = nil
  ) {
    self.maxScale = maxScale
    self.doubleTapScale = doubleTapScale
    self.backgroundColor = backgroundColor
    self.transitionCornerRadius = transitionCornerRadius
    self.dismissThreshold = dismissThreshold
    self.dismissVelocityThreshold = dismissVelocityThreshold
    self.closeButton = closeButton
    self.pageIndicator = pageIndicator
    self.onDismiss = onDismiss
    self.onPageChange = onPageChange
  }

  /// The default configuration.
  public static let `default` = ImageViewerConfiguration()
}

// MARK: - View Modifier

private struct ImageViewerModifier<Overlay: View>: ViewModifier {
  @Binding var isPresented: Bool
  let sources: [ImageSource]
  let initialIndex: Int
  let sourceFrames: [CGRect]?
  let configuration: ImageViewerConfiguration
  @ViewBuilder var overlay: (Int) -> Overlay

  func body(content: Content) -> some View {
    content
      .windowCover(isPresented: $isPresented) {
        ImageViewerContent(
          imageSources: sources,
          initialIndex: initialIndex,
          sourceFrames: sourceFrames,
          isPresented: $isPresented,
          configuration: configuration,
          overlay: overlay
        )
      }
  }
}
