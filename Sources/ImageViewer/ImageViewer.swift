import SwiftUI
import UIKit

// MARK: - Public API

extension View {
  /// Presents a full-screen image viewer with zoom transition from the source frame.
  ///
  /// The viewer is displayed in a separate UIWindow, ensuring it appears above
  /// all other content including sheets and modals.
  ///
  /// - Parameters:
  ///   - isPresented: A binding to whether the image viewer is presented.
  ///   - image: The image to display.
  ///   - sourceFrame: The frame of the source image in global coordinates.
  ///                  Use the `readFrame` modifier to obtain this value.
  ///   - configuration: Optional configuration for customizing the viewer behavior.
  ///
  /// - Returns: A view that presents the image viewer when `isPresented` is true.
  ///
  /// Example:
  /// ```swift
  /// @State private var showViewer = false
  /// @State private var sourceFrame: CGRect = .zero
  ///
  /// Image(uiImage: image)
  ///     .readFrame { frame in
  ///         sourceFrame = frame
  ///     }
  ///     .onTapGesture {
  ///         showViewer = true
  ///     }
  ///     .imageViewer(
  ///         isPresented: $showViewer,
  ///         image: image,
  ///         sourceFrame: sourceFrame
  ///     )
  /// ```
  public func imageViewer(
    isPresented: Binding<Bool>,
    image: UIImage,
    sourceFrame: CGRect?,
    configuration: ImageViewerConfiguration = .default
  ) -> some View {
    modifier(
      ImageViewerModifier(
        isPresented: isPresented,
        image: image,
        sourceFrame: sourceFrame,
        configuration: configuration
      )
    )
  }
}

// MARK: - Configuration

/// Configuration options for the image viewer.
public struct ImageViewerConfiguration: Sendable {
  /// The maximum zoom scale. Default is 5.0.
  public var maxScale: CGFloat

  /// The zoom scale applied on double-tap. Default is 3.0.
  public var doubleTapScale: CGFloat

  /// The background color of the viewer. Default is black.
  public var backgroundColor: Color

  /// The vertical distance required to dismiss the viewer. Default is 100 points.
  public var dismissThreshold: CGFloat

  /// The velocity threshold for dismissing. Default is 500 points/second.
  public var dismissVelocityThreshold: CGFloat

  /// Creates a new configuration with the specified values.
  public init(
    maxScale: CGFloat = 5.0,
    doubleTapScale: CGFloat = 3.0,
    backgroundColor: Color = .black,
    dismissThreshold: CGFloat = 100,
    dismissVelocityThreshold: CGFloat = 500
  ) {
    self.maxScale = maxScale
    self.doubleTapScale = doubleTapScale
    self.backgroundColor = backgroundColor
    self.dismissThreshold = dismissThreshold
    self.dismissVelocityThreshold = dismissVelocityThreshold
  }

  /// The default configuration.
  public static let `default` = ImageViewerConfiguration()
}

// MARK: - View Modifier

private struct ImageViewerModifier: ViewModifier {
  @Binding var isPresented: Bool
  let image: UIImage
  let sourceFrame: CGRect?
  let configuration: ImageViewerConfiguration

  func body(content: Content) -> some View {
    content
      .windowCover(isPresented: $isPresented, sourceFrame: sourceFrame) { frame in
        FullScreenImageViewer(
          image: image,
          sourceFrame: frame,
          isPresented: $isPresented,
          configuration: configuration
        )
      }
  }
}
