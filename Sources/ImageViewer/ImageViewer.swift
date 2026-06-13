import SwiftUI
import UIKit

// MARK: - Image Viewer Context

/// Context provided to custom UI components in the image viewer.
public struct ImageViewerContext {
  /// The index of the currently displayed image.
  public let currentIndex: Int

  /// The total number of images.
  public let totalCount: Int

  /// Whether this is a single image viewer (no pagination).
  public var isSingleImage: Bool { totalCount == 1 }

  /// Action to dismiss the viewer.
  public let dismiss: () -> Void
}

// MARK: - Image Source

/// Represents a source for loading images in the viewer.
///
/// For remote images, use `.async` with your preferred image loading library:
/// ```swift
/// // With Nuke
/// .async({ try await ImagePipeline.shared.image(for: url) }, placeholder: thumbnail)
///
/// // With Kingfisher
/// .async({ try await KingfisherManager.shared.retrieveImage(with: url) }, placeholder: nil)
/// ```
public enum ImageSource: Sendable {
  /// A pre-loaded UIImage instance.
  case image(UIImage)

  /// An async closure that returns an image.
  /// Use this to integrate with your preferred image loading library (Nuke, Kingfisher, SDWebImage, etc.)
  case async(@Sendable () async throws -> UIImage, placeholder: UIImage? = nil)

  /// Returns the placeholder image if available.
  public var placeholder: UIImage? {
    switch self {
    case .image:
      return nil
    case .async(_, let placeholder):
      return placeholder
    }
  }
}

// MARK: - Configuration (Core behavior only)

/// Configuration options for the image viewer's core behavior.
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

  // MARK: - Callbacks

  /// Called when the viewer is dismissed.
  public var onDismiss: (@MainActor () -> Void)?

  /// Called when the current page changes.
  public var onPageChange: (@MainActor (Int) -> Void)?

  // MARK: - Init

  public init(
    maxScale: CGFloat = 5.0,
    doubleTapScale: CGFloat = 3.0,
    backgroundColor: Color = .black,
    transitionCornerRadius: CGFloat = 8,
    dismissThreshold: CGFloat = 100,
    dismissVelocityThreshold: CGFloat = 500,
    onDismiss: (@MainActor () -> Void)? = nil,
    onPageChange: (@MainActor (Int) -> Void)? = nil
  ) {
    self.maxScale = maxScale
    self.doubleTapScale = doubleTapScale
    self.backgroundColor = backgroundColor
    self.transitionCornerRadius = transitionCornerRadius
    self.dismissThreshold = dismissThreshold
    self.dismissVelocityThreshold = dismissVelocityThreshold
    self.onDismiss = onDismiss
    self.onPageChange = onPageChange
  }

  public static let `default` = ImageViewerConfiguration()
}

// MARK: - Default UI Components

/// Default close button for the image viewer.
public struct DefaultCloseButton: View {
  let dismiss: () -> Void

  public init(dismiss: @escaping () -> Void) {
    self.dismiss = dismiss
  }

  public var body: some View {
    if #available(iOS 26, *) {
      Button(action: dismiss) {
        Image(systemName: "xmark")
          .font(.body.weight(.semibold))
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)
      }
      .buttonStyle(.glass)
      .accessibilityLabel(Text("Close"))
      .accessibilityHint(Text("Closes the image viewer"))
    } else {
      Button(action: dismiss) {
        Image(systemName: "xmark.circle.fill")
          .font(.title)
          .symbolRenderingMode(.palette)
          .foregroundStyle(.white, .black.opacity(0.5))
          .frame(width: 44, height: 44)
      }
      .accessibilityLabel(Text("Close"))
      .accessibilityHint(Text("Closes the image viewer"))
    }
  }
}

/// Default page indicator (dots) for the image viewer.
public struct DefaultPageIndicator: View {
  let currentIndex: Int
  let totalCount: Int

  public init(currentIndex: Int, totalCount: Int) {
    self.currentIndex = currentIndex
    self.totalCount = totalCount
  }

  public var body: some View {
    if #available(iOS 26, *) {
      dots
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(in: .capsule)
        .accessibilityHidden(true)
    } else {
      dots
        .accessibilityHidden(true)
    }
  }

  private var dots: some View {
    HStack(spacing: 6) {
      ForEach(0..<totalCount, id: \.self) { index in
        Circle()
          .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
          .frame(width: 6, height: 6)
      }
    }
  }
}

/// Default loading view for the image viewer.
public struct DefaultLoadingView: View {
  public init() {}

  public var body: some View {
    ProgressView()
      .tint(.white)
  }
}

/// Default error view for the image viewer.
public struct DefaultErrorView: View {
  let error: Error

  public init(error: Error) {
    self.error = error
  }

  public var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.white.opacity(0.6))

      Text("Failed to load image")
        .foregroundStyle(.white.opacity(0.8))
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text("Failed to load image"))
  }
}

// MARK: - Public API

extension View {

  // MARK: - Full Customization API

  /// Presents a fully customizable image viewer.
  ///
  /// This is the most flexible API, allowing complete customization of all UI components.
  ///
  /// - Parameters:
  ///   - isPresented: A binding to whether the image viewer is presented.
  ///   - sources: The array of image sources to display.
  ///   - initialIndex: The index of the image to display initially.
  ///   - sourceFrames: Optional array of source frames for zoom transitions.
  ///   - sourceContentMode: The content mode used for source thumbnails (.fit or .fill).
  ///   - configuration: Configuration for core behavior.
  ///   - overlay: Custom overlay content.
  ///   - closeButton: Custom close button.
  ///   - pageIndicator: Custom page indicator.
  ///   - loadingContent: Custom loading view.
  ///   - errorContent: Custom error view.
  public func imageViewer<
    Overlay: View,
    CloseButton: View,
    PageIndicator: View,
    LoadingContent: View,
    ErrorContent: View
  >(
    isPresented: Binding<Bool>,
    sources: [ImageSource],
    initialIndex: Int = 0,
    sourceFrames: [CGRect]? = nil,
    sourceContentMode: ContentMode = .fit,
    configuration: ImageViewerConfiguration = .default,
    @ViewBuilder overlay: @escaping (ImageViewerContext) -> Overlay,
    @ViewBuilder closeButton: @escaping (_ dismiss: @escaping () -> Void) -> CloseButton,
    @ViewBuilder pageIndicator: @escaping (_ currentIndex: Int, _ totalCount: Int) -> PageIndicator,
    @ViewBuilder loadingContent: @escaping () -> LoadingContent,
    @ViewBuilder errorContent: @escaping (Error) -> ErrorContent
  ) -> some View {
    modifier(
      ImageViewerModifier(
        isPresented: isPresented,
        sources: sources,
        initialIndex: initialIndex,
        sourceFrames: sourceFrames,
        sourceContentMode: sourceContentMode,
        configuration: configuration,
        overlay: overlay,
        closeButton: closeButton,
        pageIndicator: pageIndicator,
        loadingContent: loadingContent,
        errorContent: errorContent
      )
    )
  }

  // MARK: - Simple API with Default UI

  /// Presents an image viewer with default UI components.
  ///
  /// Example:
  /// ```swift
  /// .imageViewer(
  ///     isPresented: $showViewer,
  ///     images: images,
  ///     initialIndex: selectedIndex
  /// )
  /// ```
  public func imageViewer(
    isPresented: Binding<Bool>,
    sources: [ImageSource],
    initialIndex: Int = 0,
    sourceFrames: [CGRect]? = nil,
    sourceContentMode: ContentMode = .fit,
    configuration: ImageViewerConfiguration = .default
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      sources: sources,
      initialIndex: initialIndex,
      sourceFrames: sourceFrames,
      sourceContentMode: sourceContentMode,
      configuration: configuration,
      overlay: { _ in EmptyView() },
      closeButton: { DefaultCloseButton(dismiss: $0) },
      pageIndicator: { DefaultPageIndicator(currentIndex: $0, totalCount: $1) },
      loadingContent: { DefaultLoadingView() },
      errorContent: { DefaultErrorView(error: $0) }
    )
  }

  /// Presents an image viewer with default UI and custom overlay.
  public func imageViewer<Overlay: View>(
    isPresented: Binding<Bool>,
    sources: [ImageSource],
    initialIndex: Int = 0,
    sourceFrames: [CGRect]? = nil,
    sourceContentMode: ContentMode = .fit,
    configuration: ImageViewerConfiguration = .default,
    @ViewBuilder overlay: @escaping (ImageViewerContext) -> Overlay
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      sources: sources,
      initialIndex: initialIndex,
      sourceFrames: sourceFrames,
      sourceContentMode: sourceContentMode,
      configuration: configuration,
      overlay: overlay,
      closeButton: { DefaultCloseButton(dismiss: $0) },
      pageIndicator: { DefaultPageIndicator(currentIndex: $0, totalCount: $1) },
      loadingContent: { DefaultLoadingView() },
      errorContent: { DefaultErrorView(error: $0) }
    )
  }

  // MARK: - UIImage Convenience

  /// Presents an image viewer for a single UIImage.
  public func imageViewer(
    isPresented: Binding<Bool>,
    image: UIImage,
    sourceFrame: CGRect? = nil,
    sourceContentMode: ContentMode = .fit,
    configuration: ImageViewerConfiguration = .default
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      sources: [.image(image)],
      initialIndex: 0,
      sourceFrames: sourceFrame.map { [$0] },
      sourceContentMode: sourceContentMode,
      configuration: configuration
    )
  }

  /// Presents an image viewer for multiple UIImages.
  public func imageViewer(
    isPresented: Binding<Bool>,
    images: [UIImage],
    initialIndex: Int = 0,
    sourceFrames: [CGRect]? = nil,
    sourceContentMode: ContentMode = .fit,
    configuration: ImageViewerConfiguration = .default
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      sources: images.map { .image($0) },
      initialIndex: initialIndex,
      sourceFrames: sourceFrames,
      sourceContentMode: sourceContentMode,
      configuration: configuration
    )
  }

  /// Presents an image viewer for multiple UIImages with custom overlay.
  public func imageViewer<Overlay: View>(
    isPresented: Binding<Bool>,
    images: [UIImage],
    initialIndex: Int = 0,
    sourceFrames: [CGRect]? = nil,
    sourceContentMode: ContentMode = .fit,
    configuration: ImageViewerConfiguration = .default,
    @ViewBuilder overlay: @escaping (ImageViewerContext) -> Overlay
  ) -> some View {
    imageViewer(
      isPresented: isPresented,
      sources: images.map { .image($0) },
      initialIndex: initialIndex,
      sourceFrames: sourceFrames,
      sourceContentMode: sourceContentMode,
      configuration: configuration,
      overlay: overlay
    )
  }

}

// MARK: - View Modifier

private struct ImageViewerModifier<
  Overlay: View,
  CloseButton: View,
  PageIndicator: View,
  LoadingContent: View,
  ErrorContent: View
>: ViewModifier {
  @Binding var isPresented: Bool
  let sources: [ImageSource]
  let initialIndex: Int
  let sourceFrames: [CGRect]?
  let sourceContentMode: ContentMode
  let configuration: ImageViewerConfiguration
  @ViewBuilder var overlay: (ImageViewerContext) -> Overlay
  @ViewBuilder var closeButton: (_ dismiss: @escaping () -> Void) -> CloseButton
  @ViewBuilder var pageIndicator: (_ currentIndex: Int, _ totalCount: Int) -> PageIndicator
  @ViewBuilder var loadingContent: () -> LoadingContent
  @ViewBuilder var errorContent: (Error) -> ErrorContent

  @State private var windowManager: WindowCoverManager?

  func body(content: Content) -> some View {
    content
      .onChange(of: isPresented) { _, newValue in
        if newValue {
          showViewer()
        } else {
          hideViewer()
        }
      }
  }

  private func showViewer() {
    guard windowManager == nil else { return }

    // Do not present if there are no images
    guard !sources.isEmpty else {
      isPresented = false
      return
    }

    let manager = WindowCoverManager()
    windowManager = manager

    let controller = ImageViewerController(
      imageSources: sources,
      initialIndex: initialIndex,
      sourceFrames: sourceFrames,
      sourceContentMode: sourceContentMode,
      configuration: configuration,
      overlay: overlay,
      closeButton: closeButton,
      pageIndicator: pageIndicator,
      loadingContent: loadingContent,
      errorContent: errorContent
    )

    controller.onDismiss = { [self] in
      isPresented = false
      hideViewer()
    }

    // If no active scene is available, the window cannot be presented.
    // Roll back state so the viewer can be presented again later.
    guard manager.show(viewController: controller) else {
      windowManager = nil
      isPresented = false
      return
    }
  }

  private func hideViewer() {
    windowManager?.hide()
    windowManager = nil
  }
}
