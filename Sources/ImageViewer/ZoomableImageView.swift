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
    transitionState: Binding<ImageTransitionState>,
    hasAppeared: Binding<Bool>,
    onDismiss: @escaping () -> Void
  ) {
    self.image = image
    self.sourceFrame = sourceFrame
    self.sourceContentMode = sourceContentMode
    self.configuration = configuration
    self.isCurrentPage = isCurrentPage
    self._transitionState = transitionState
    self._hasAppeared = hasAppeared
    self.onDismiss = onDismiss
  }

  // MARK: - Computed Properties

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

  var currentDismissProgress: CGFloat {
    dismissProgress
  }

  var showsControls: Bool {
    transitionState == .presented || transitionState == .interactive
  }

  // MARK: - Body

  var body: some View {
    GeometryReader { geometry in
      imageView(in: geometry)
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

  // MARK: - Image View

  private func imageView(in geometry: GeometryProxy) -> some View {
    let finalFrame = calculateFinalFrame(in: geometry)
    let localSourceFrame = convertToLocalFrame(sourceFrame, in: geometry)
    let transitionParams = calculateTransitionParams(
      finalFrame: finalFrame,
      localSourceFrame: localSourceFrame,
      geometrySize: geometry.size
    )
    let totalOffset = CGSize(
      width: offset.width + dragOffset.width,
      height: offset.height + dragOffset.height
    )

    return ZStack {
      if sourceContentMode == .fill && transitionParams.needsClipping {
        // Fill mode with clipping - use container approach
        fillModeImage(
          transitionParams: transitionParams,
          finalFrame: finalFrame,
          totalOffset: totalOffset,
          in: geometry
        )
      } else {
        // Fit mode or no clipping needed
        fitModeImage(
          transitionParams: transitionParams,
          totalOffset: totalOffset,
          in: geometry
        )
      }
    }
    .gesture(combinedGesture(in: geometry))
    .onTapGesture(count: 2) { location in
      handleDoubleTap(at: location, in: geometry)
    }
    .accessibilityElement()
    .accessibilityLabel(Text("Image"))
    .accessibilityAddTraits(.isImage)
    .accessibilityHint(Text("Double tap to zoom, drag to dismiss"))
    .accessibilityAction(.magicTap) {
      onDismiss()
    }
  }

  private func fitModeImage(
    transitionParams: TransitionParams,
    totalOffset: CGSize,
    in geometry: GeometryProxy
  ) -> some View {
    Image(uiImage: image)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(width: transitionParams.containerSize.width, height: transitionParams.containerSize.height)
      .clipShape(RoundedRectangle(cornerRadius: transitionParams.cornerRadius))
      .scaleEffect(scale)
      .position(
        x: transitionParams.position.x + totalOffset.width,
        y: transitionParams.position.y + totalOffset.height
      )
  }

  private func fillModeImage(
    transitionParams: TransitionParams,
    finalFrame: CGRect,
    totalOffset: CGSize,
    in geometry: GeometryProxy
  ) -> some View {
    // Container that clips the content
    Rectangle()
      .fill(.clear)
      .frame(width: transitionParams.containerSize.width, height: transitionParams.containerSize.height)
      .overlay {
        // Image scaled to fill the container
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: finalFrame.width, height: finalFrame.height)
          .scaleEffect(transitionParams.imageScale)
      }
      .clipShape(RoundedRectangle(cornerRadius: transitionParams.cornerRadius))
      .scaleEffect(scale)
      .position(
        x: transitionParams.position.x + totalOffset.width,
        y: transitionParams.position.y + totalOffset.height
      )
  }

  // MARK: - Transition Parameters

  private struct TransitionParams {
    var containerSize: CGSize
    var imageScale: CGFloat
    var position: CGPoint
    var cornerRadius: CGFloat
    var needsClipping: Bool
  }

  private func calculateTransitionParams(
    finalFrame: CGRect,
    localSourceFrame: CGRect?,
    geometrySize: CGSize
  ) -> TransitionParams {
    let isTransitioning = transitionState == .appearing || transitionState == .dismissing
    let isInteractive = transitionState == .interactive

    // Default (presented state)
    var params = TransitionParams(
      containerSize: finalFrame.size,
      imageScale: 1.0,
      position: CGPoint(x: geometrySize.width / 2, y: geometrySize.height / 2),
      cornerRadius: 0,
      needsClipping: false
    )

    guard let sourceFrame = localSourceFrame else {
      return params
    }

    if isTransitioning {
      if sourceContentMode == .fill {
        // Fill mode: container is sourceFrame size, image is scaled to fill
        let fillScale = calculateFillScale(imageSize: finalFrame.size, containerSize: sourceFrame.size)
        params.containerSize = sourceFrame.size
        params.imageScale = fillScale
        params.position = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
        params.needsClipping = true
      } else {
        // Fit mode: just resize to source frame
        params.containerSize = sourceFrame.size
        params.imageScale = 1.0
        params.position = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
        params.needsClipping = false
      }
      params.cornerRadius = configuration.transitionCornerRadius
    } else if isInteractive {
      let progress = dismissProgress

      if sourceContentMode == .fill {
        // Interpolate from presented to source
        let fillScale = calculateFillScale(imageSize: finalFrame.size, containerSize: sourceFrame.size)

        params.containerSize = CGSize(
          width: finalFrame.width + (sourceFrame.width - finalFrame.width) * progress,
          height: finalFrame.height + (sourceFrame.height - finalFrame.height) * progress
        )
        params.imageScale = 1.0 + (fillScale - 1.0) * progress

        let presentedPosition = CGPoint(x: geometrySize.width / 2, y: geometrySize.height / 2)
        let sourcePosition = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
        params.position = CGPoint(
          x: presentedPosition.x + (sourcePosition.x - presentedPosition.x) * progress,
          y: presentedPosition.y + (sourcePosition.y - presentedPosition.y) * progress
        )
        params.needsClipping = true
      } else {
        // Fit mode interactive
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
        params.needsClipping = false
      }
    }

    return params
  }

  private func calculateFillScale(imageSize: CGSize, containerSize: CGSize) -> CGFloat {
    guard imageSize.width > 0, imageSize.height > 0 else { return 1.0 }
    let scaleX = containerSize.width / imageSize.width
    let scaleY = containerSize.height / imageSize.height
    return max(scaleX, scaleY)
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

  private func combinedGesture(in geometry: GeometryProxy) -> some Gesture {
    SimultaneousGesture(
      magnificationGesture(),
      dragGesture(in: geometry)
    )
  }

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
