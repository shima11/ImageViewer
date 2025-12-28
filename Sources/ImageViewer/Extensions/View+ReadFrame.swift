import SwiftUI

// MARK: - Source Frame Preference Key

struct SourceFramePreferenceKey: PreferenceKey {
  static let defaultValue: CGRect = .zero

  static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
    value = nextValue()
  }
}

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
          .preference(key: SourceFramePreferenceKey.self, value: geometry.frame(in: coordinateSpace))
          .onPreferenceChange(SourceFramePreferenceKey.self, perform: onChange)
      }
    )
  }
}
