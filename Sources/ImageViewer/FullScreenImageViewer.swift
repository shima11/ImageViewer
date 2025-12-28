import SwiftUI

// MARK: - Full Screen Image Viewer

/// A full-screen image viewer with zoom and interactive dismiss support.
struct FullScreenImageViewer: View {
  let image: UIImage
  let sourceFrame: CGRect?
  @Binding var isPresented: Bool
  let configuration: ImageViewerConfiguration

  // MARK: - Transition State

  enum TransitionState {
    case appearing
    case presented
    case dismissing
    case interactive
  }

  // MARK: - State

  @State private var transitionState: TransitionState = .appearing
  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  @State private var dragOffset: CGSize = .zero
  @State private var dismissProgress: CGFloat = 0

  private let minScale: CGFloat = 1.0

  // MARK: - Computed Properties

  private var backgroundOpacity: Double {
    switch transitionState {
    case .appearing, .dismissing:
      return 0
    case .presented:
      return 1.0
    case .interactive:
      return 1.0 - Double(dismissProgress) * 0.8
    }
  }

  private var showCloseButton: Bool {
    transitionState == .presented || transitionState == .interactive
  }

  // MARK: - Body

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Background
        configuration.backgroundColor
          .opacity(backgroundOpacity)
          .ignoresSafeArea()
          .onTapGesture {
            dismissToSource()
          }

        // Image with zoom transition
        imageView(in: geometry)
      }
    }
    .overlay(alignment: .topTrailing) {
      closeButton
    }
    .ignoresSafeArea()
    .statusBarHidden()
    .onAppear {
      // Start appear animation after a brief delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
          transitionState = .presented
        }
      }
    }
  }

  // MARK: - Image View

  private func imageView(in geometry: GeometryProxy) -> some View {
    let finalFrame = calculateFinalFrame(in: geometry)
    let currentFrame = calculateCurrentFrame(finalFrame: finalFrame)
    let totalOffset = CGSize(
      width: offset.width + dragOffset.width,
      height: offset.height + dragOffset.height
    )

    return Image(uiImage: image)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(width: currentFrame.width, height: currentFrame.height)
      .clipped()
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius(for: transitionState)))
      .scaleEffect(scale)
      .position(
        x: currentFrame.midX + totalOffset.width,
        y: currentFrame.midY + totalOffset.height
      )
      .gesture(combinedGesture(in: geometry))
      .onTapGesture(count: 2) { location in
        handleDoubleTap(at: location, in: geometry)
      }
  }

  private func calculateFinalFrame(in geometry: GeometryProxy) -> CGRect {
    let screenSize = geometry.size
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

  private func calculateCurrentFrame(finalFrame: CGRect) -> CGRect {
    switch transitionState {
    case .appearing, .dismissing:
      return sourceFrame ?? finalFrame
    case .presented:
      return finalFrame
    case .interactive:
      if let source = sourceFrame {
        return interpolateFrame(from: finalFrame, to: source, progress: dismissProgress)
      }
      return finalFrame
    }
  }

  private func cornerRadius(for state: TransitionState) -> CGFloat {
    switch state {
    case .appearing, .dismissing:
      return 8
    case .presented, .interactive:
      return 0
    }
  }

  private func interpolateFrame(from: CGRect, to: CGRect, progress: CGFloat) -> CGRect {
    let p = min(max(progress, 0), 1)
    return CGRect(
      x: from.origin.x + (to.origin.x - from.origin.x) * p,
      y: from.origin.y + (to.origin.y - from.origin.y) * p,
      width: from.width + (to.width - from.width) * p,
      height: from.height + (to.height - from.height) * p
    )
  }

  // MARK: - Close Button

  private var closeButton: some View {
    Button {
      dismissToSource()
    } label: {
      ZStack {
        Image(systemName: "xmark.circle.fill")
          .font(.title)
          .symbolRenderingMode(.palette)
          .foregroundStyle(.white, .black.opacity(0.5))
          .frame(width: 44, height: 44)
      }
    }
    .padding(.top, 8)
    .padding(.trailing, 8)
    .padding(.top, safeAreaInsets.top)
    .opacity(showCloseButton ? 1.0 - Double(dismissProgress) : 0.0)
  }

  private var safeAreaInsets: UIEdgeInsets {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?
      .windows
      .first?
      .safeAreaInsets ?? .zero
  }

  // MARK: - Dismiss

  private func dismissToSource() {
    // Animate the image back to source position
    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
      transitionState = .dismissing
      scale = 1.0
      offset = .zero
      dragOffset = .zero
    }
    // Wait for animation to complete before hiding the window
    // This prevents flickering by ensuring the window image is at source position
    // before the source image becomes visible again
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      isPresented = false
    }
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
          // Interactive dismiss gesture
          transitionState = .interactive
          dragOffset = value.translation
          let progress = abs(value.translation.height) / 300
          dismissProgress = min(progress, 1.0)
        } else {
          // Pan gesture when zoomed
          offset = CGSize(
            width: lastOffset.width + value.translation.width / scale,
            height: lastOffset.height + value.translation.height / scale
          )
        }
      }
      .onEnded { value in
        if scale <= 1.0 {
          // Check if should dismiss
          let shouldDismiss = abs(value.translation.height) > configuration.dismissThreshold
            || abs(value.velocity.height) > configuration.dismissVelocityThreshold

          if shouldDismiss {
            dismissToSource()
          } else {
            withAnimation(.spring(duration: 0.3)) {
              transitionState = .presented
              dragOffset = .zero
              dismissProgress = 0
            }
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
}
