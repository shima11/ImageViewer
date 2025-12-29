import SwiftUI

// MARK: - View Extension

extension View {
  /// Reads the frame of this view in the specified coordinate space.
  ///
  /// Use this modifier to track the position of the source image for zoom transitions.
  ///
  /// - Parameters:
  ///   - coordinateSpace: The coordinate space to use. Default is `.global`.
  ///   - onChange: A closure called when the frame changes.
  ///
  /// - Returns: A view that reports its frame.
  ///
  /// Example:
  /// ```swift
  /// @State private var sourceFrame: CGRect = .zero
  ///
  /// Image(uiImage: image)
  ///     .readFrame { frame in
  ///         sourceFrame = frame
  ///     }
  /// ```
  public func readFrame(
    in coordinateSpace: CoordinateSpace = .global,
    onChange: @escaping (CGRect) -> Void
  ) -> some View {
    background(
      GeometryReader { geometry in
        Color.clear
          .onAppear {
            onChange(geometry.frame(in: coordinateSpace))
          }
          .onChange(of: geometry.frame(in: coordinateSpace)) { _, newFrame in
            onChange(newFrame)
          }
      }
    )
  }
}
