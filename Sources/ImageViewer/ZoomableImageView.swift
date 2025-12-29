import SwiftUI

// MARK: - Transition State

enum ImageTransitionState: Sendable {
  case appearing
  case presented
  case dismissing
  case interactive
}

// MARK: - Zoomable Image View

/// A reusable image view with zoom, pan, and interactive dismiss gestures.
struct ZoomableImageView: View {
  let image: UIImage
  let sourceFrame: CGRect?
  let sourceContentMode: ContentMode
  let configuration: ImageViewerConfiguration
  let isCurrentPage: Bool
  let allowsDismissGesture: Bool
  let onDismiss: () -> Void

  @Binding var transitionState: ImageTransitionState
  @Binding var hasAppeared: Bool

  // MARK: - State

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  @State private var dragOffset: CGSize = .zero
  @State private var dismissProgress: CGFloat = 0

  private let minScale: CGFloat = 1.0

  // MARK: - Init

  init(
    image: UIImage,
    sourceFrame: CGRect?,
    sourceContentMode: ContentMode = .fit,
    configuration: ImageViewerConfiguration,
    isCurrentPage: Bool = true,
    allowsDismissGesture: Bool = true,
    transitionState: Binding<ImageTransitionState>,
    hasAppeared: Binding<Bool>,
    onDismiss: @escaping () -> Void
  ) {
    self.image = image
    self.sourceFrame = sourceFrame
    self.sourceContentMode = sourceContentMode
    self.configuration = configuration
    self.isCurrentPage = isCurrentPage
    self.allowsDismissGesture = allowsDismissGesture
    self._transitionState = transitionState
    self._hasAppeared = hasAppeared
    self.onDismiss = onDismiss
  }

  // MARK: - Computed Properties

  /// Whether drag gesture should be enabled.
  /// Only enable when: dismiss is allowed OR zoomed in (need pan).
  private var shouldEnableDragGesture: Bool {
    allowsDismissGesture || scale > 1.0
  }

  var backgroundOpacity: Double {
    switch transitionState {
    case .appearing, .dismissing:
      return 0
    case .presented:
      return 1.0
    case .interactive:
      return 1.0 - Double(dismissProgress) * 0.8
    }
  }

  var showsControls: Bool {
    transitionState == .presented || transitionState == .interactive
  }

  // MARK: - Body

  var body: some View {
    GeometryReader { geometry in
      let finalFrame = calculateFinalFrame(in: geometry)
      let localSourceFrame = convertToLocalFrame(sourceFrame, in: geometry)
      let params = calculateTransitionParams(
        finalFrame: finalFrame,
        localSourceFrame: localSourceFrame,
        geometrySize: geometry.size
      )

      // Single unified view structure for smooth animation
      imageWithGestures(params: params, finalFrame: finalFrame, in: geometry)
        .accessibilityElement()
        .accessibilityLabel(Text("Image"))
        .accessibilityAddTraits(.isImage)
        .accessibilityHint(Text("Double tap to zoom, drag to dismiss"))
        .accessibilityAction(.magicTap) {
          onDismiss()
        }
    }
    .onChange(of: isCurrentPage) { _, newValue in
      if newValue {
        resetZoom()
      }
    }
    .onAppear {
      startAppearAnimation()
    }
  }

  // MARK: - Image With Gestures

  @ViewBuilder
  private func imageWithGestures(
    params: TransitionParams,
    finalFrame: CGRect,
    in geometry: GeometryProxy
  ) -> some View {
    let content = imageContent(params: params, finalFrame: finalFrame, in: geometry)
      .gesture(magnificationGesture())
      .onTapGesture(count: 2) { location in
        handleDoubleTap(at: location, in: geometry)
      }

    // Only attach drag gesture when needed (dismiss allowed OR zoomed)
    // This allows UIKit gestures to work in multi-image mode when not zoomed
    if shouldEnableDragGesture {
      content.gesture(dragGesture(in: geometry))
    } else {
      content
    }
  }

  // MARK: - Image Content

  @ViewBuilder
  private func imageContent(
    params: TransitionParams,
    finalFrame: CGRect,
    in geometry: GeometryProxy
  ) -> some View {
    let totalOffset = CGSize(
      width: offset.width + dragOffset.width,
      height: offset.height + dragOffset.height
    )

    // Use a single view structure that animates all properties
    Color.clear
      .frame(width: params.containerSize.width, height: params.containerSize.height)
      .overlay {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: finalFrame.width, height: finalFrame.height)
          .scaleEffect(params.imageScale)
      }
      .clipped()
      .clipShape(RoundedRectangle(cornerRadius: params.cornerRadius))
      .scaleEffect(scale)
      .position(
        x: params.position.x + totalOffset.width,
        y: params.position.y + totalOffset.height
      )
  }

  // MARK: - Transition Parameters

  private struct TransitionParams {
    var containerSize: CGSize
    var imageScale: CGFloat
    var position: CGPoint
    var cornerRadius: CGFloat
  }

  private func calculateTransitionParams(
    finalFrame: CGRect,
    localSourceFrame: CGRect?,
    geometrySize: CGSize
  ) -> TransitionParams {
    let isTransitioning = transitionState == .appearing || transitionState == .dismissing
    let isInteractive = transitionState == .interactive

    // Default (presented state) - container matches final frame, no extra scaling
    var params = TransitionParams(
      containerSize: finalFrame.size,
      imageScale: 1.0,
      position: CGPoint(x: geometrySize.width / 2, y: geometrySize.height / 2),
      cornerRadius: 0
    )

    guard let sourceFrame = localSourceFrame else {
      return params
    }

    if isTransitioning {
      // Transition to/from source
      params.containerSize = sourceFrame.size
      params.position = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
      params.cornerRadius = configuration.transitionCornerRadius

      if sourceContentMode == .fill {
        // Scale image to fill the source container
        params.imageScale = calculateFillScale(imageSize: finalFrame.size, containerSize: sourceFrame.size)
      } else {
        // Scale image to fit the source container
        params.imageScale = calculateFitScale(imageSize: finalFrame.size, containerSize: sourceFrame.size)
      }
    } else if isInteractive {
      // Interactive dismiss - interpolate from presented to source
      let progress = dismissProgress

      params.containerSize = CGSize(
        width: finalFrame.width + (sourceFrame.width - finalFrame.width) * progress,
        height: finalFrame.height + (sourceFrame.height - finalFrame.height) * progress
      )

      let presentedPosition = CGPoint(x: geometrySize.width / 2, y: geometrySize.height / 2)
      let sourcePosition = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
      params.position = CGPoint(
        x: presentedPosition.x + (sourcePosition.x - presentedPosition.x) * progress,
        y: presentedPosition.y + (sourcePosition.y - presentedPosition.y) * progress
      )

      if sourceContentMode == .fill {
        let targetScale = calculateFillScale(imageSize: finalFrame.size, containerSize: sourceFrame.size)
        params.imageScale = 1.0 + (targetScale - 1.0) * progress
      } else {
        let targetScale = calculateFitScale(imageSize: finalFrame.size, containerSize: sourceFrame.size)
        params.imageScale = 1.0 + (targetScale - 1.0) * progress
      }

      params.cornerRadius = configuration.transitionCornerRadius * progress
    }

    return params
  }

  private func calculateFillScale(imageSize: CGSize, containerSize: CGSize) -> CGFloat {
    guard imageSize.width > 0, imageSize.height > 0 else { return 1.0 }
    let scaleX = containerSize.width / imageSize.width
    let scaleY = containerSize.height / imageSize.height
    return max(scaleX, scaleY)
  }

  private func calculateFitScale(imageSize: CGSize, containerSize: CGSize) -> CGFloat {
    guard imageSize.width > 0, imageSize.height > 0 else { return 1.0 }
    let scaleX = containerSize.width / imageSize.width
    let scaleY = containerSize.height / imageSize.height
    return min(scaleX, scaleY)
  }

  // MARK: - Frame Calculations

  private func calculateFinalFrame(in geometry: GeometryProxy) -> CGRect {
    let screenSize = geometry.size
    guard image.size.height > 0 else {
      return CGRect(origin: .zero, size: screenSize)
    }

    let imageAspect = image.size.width / image.size.height
    let screenAspect = screenSize.width / screenSize.height

    let finalSize: CGSize
    if imageAspect > screenAspect {
      finalSize = CGSize(width: screenSize.width, height: screenSize.width / imageAspect)
    } else {
      finalSize = CGSize(width: screenSize.height * imageAspect, height: screenSize.height)
    }

    return CGRect(
      x: (screenSize.width - finalSize.width) / 2,
      y: (screenSize.height - finalSize.height) / 2,
      width: finalSize.width,
      height: finalSize.height
    )
  }

  private func convertToLocalFrame(_ globalFrame: CGRect?, in geometry: GeometryProxy) -> CGRect? {
    guard let frame = globalFrame else { return nil }
    let geometryGlobalFrame = geometry.frame(in: .global)
    return CGRect(
      x: frame.origin.x - geometryGlobalFrame.origin.x,
      y: frame.origin.y - geometryGlobalFrame.origin.y,
      width: frame.width,
      height: frame.height
    )
  }

  // MARK: - Gestures

  private func magnificationGesture() -> some Gesture {
    MagnifyGesture()
      .onChanged { value in
        guard transitionState == .presented || transitionState == .interactive else { return }
        let newScale = lastScale * value.magnification
        scale = min(max(newScale, minScale * 0.5), configuration.maxScale)
      }
      .onEnded { _ in
        withAnimation(.spring(duration: 0.3)) {
          if scale < minScale {
            scale = minScale
            offset = .zero
          }
          lastScale = scale
        }
      }
  }

  private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
    DragGesture()
      .onChanged { value in
        guard transitionState == .presented || transitionState == .interactive else { return }

        if scale <= 1.0 {
          // Only handle dismiss gesture if allowed
          guard allowsDismissGesture else { return }

          transitionState = .interactive
          dragOffset = value.translation
          let progress = abs(value.translation.height) / 300
          dismissProgress = min(progress, 1.0)
        } else {
          offset = CGSize(
            width: lastOffset.width + value.translation.width / scale,
            height: lastOffset.height + value.translation.height / scale
          )
        }
      }
      .onEnded { value in
        if scale <= 1.0 {
          // Only handle dismiss gesture if allowed
          guard allowsDismissGesture else { return }

          let shouldDismiss = abs(value.translation.height) > configuration.dismissThreshold
            || abs(value.velocity.height) > configuration.dismissVelocityThreshold

          if shouldDismiss {
            performDismiss()
          } else {
            cancelDismiss()
          }
        } else {
          lastOffset = offset
          withAnimation(.spring(duration: 0.3)) {
            limitOffset(in: geometry)
          }
        }
      }
  }

  // MARK: - Double Tap

  private func handleDoubleTap(at location: CGPoint, in geometry: GeometryProxy) {
    guard transitionState == .presented else { return }

    withAnimation(.spring(duration: 0.3)) {
      if scale > minScale {
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
      } else {
        scale = configuration.doubleTapScale
        lastScale = configuration.doubleTapScale

        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let offsetX = (center.x - location.x) / configuration.doubleTapScale
        let offsetY = (center.y - location.y) / configuration.doubleTapScale
        offset = CGSize(width: offsetX, height: offsetY)
        lastOffset = offset
      }
    }
  }

  // MARK: - Helpers

  private func limitOffset(in geometry: GeometryProxy) {
    let maxOffsetX = max(0, (geometry.size.width * (scale - 1)) / (2 * scale))
    let maxOffsetY = max(0, (geometry.size.height * (scale - 1)) / (2 * scale))

    offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
    offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
    lastOffset = offset
  }

  private func resetZoom() {
    withAnimation(.spring(duration: 0.3)) {
      scale = 1.0
      lastScale = 1.0
      offset = .zero
      lastOffset = .zero
    }
  }

  private func startAppearAnimation() {
    guard transitionState == .appearing else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
      withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
        transitionState = .presented
        hasAppeared = true
      }
    }
  }

  private func performDismiss() {
    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
      transitionState = .dismissing
      scale = 1.0
      offset = .zero
      dragOffset = .zero
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      onDismiss()
    }
  }

  private func cancelDismiss() {
    withAnimation(.spring(duration: 0.3)) {
      transitionState = .presented
      dragOffset = .zero
      dismissProgress = 0
    }
  }
}
