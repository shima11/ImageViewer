import SwiftUI

// MARK: - Image Viewer Content

/// The main image viewer component supporting single and multiple images.
struct ImageViewerContent<Overlay: View>: View {
  let imageSources: [ImageSource]
  let initialIndex: Int
  let sourceFrames: [CGRect]?
  @Binding var isPresented: Bool
  let configuration: ImageViewerConfiguration
  let overlay: (Int) -> Overlay

  // MARK: - State

  @State private var currentIndex: Int
  @State private var transitionState: ImageTransitionState = .appearing
  @State private var hasAppeared = false

  // MARK: - Init

  init(
    imageSources: [ImageSource],
    initialIndex: Int,
    sourceFrames: [CGRect]?,
    isPresented: Binding<Bool>,
    configuration: ImageViewerConfiguration,
    @ViewBuilder overlay: @escaping (Int) -> Overlay
  ) {
    self.imageSources = imageSources
    let validIndex = max(0, min(initialIndex, max(0, imageSources.count - 1)))
    self.initialIndex = validIndex
    self.sourceFrames = sourceFrames
    self._isPresented = isPresented
    self.configuration = configuration
    self.overlay = overlay
    self._currentIndex = State(initialValue: validIndex)
  }

  // MARK: - Computed Properties

  private var isSingleImage: Bool {
    imageSources.count == 1
  }

  private var showsControls: Bool {
    transitionState == .presented || transitionState == .interactive
  }

  private var backgroundOpacity: Double {
    switch transitionState {
    case .appearing, .dismissing:
      return 0
    case .presented:
      return 1.0
    case .interactive:
      return 0.6
    }
  }

  // MARK: - Body

  var body: some View {
    Group {
      if imageSources.isEmpty {
        emptyStateView
      } else {
        viewerContent
      }
    }
    .ignoresSafeArea()
    .statusBarHidden()
    .accessibilityAction(.escape) {
      dismiss()
    }
    .onChange(of: currentIndex) { oldValue, newValue in
      if oldValue != newValue {
        configuration.onPageChange?(newValue)
      }
    }
  }

  // MARK: - Empty State

  private var emptyStateView: some View {
    ZStack {
      configuration.backgroundColor
        .ignoresSafeArea()

      VStack(spacing: 16) {
        Image(systemName: "photo.on.rectangle.angled")
          .font(.largeTitle)
          .foregroundStyle(.white.opacity(0.6))

        Text("No images")
          .foregroundStyle(.white.opacity(0.8))
      }
    }
    .onTapGesture {
      isPresented = false
      configuration.onDismiss?()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text("No images available"))
    .accessibilityHint(Text("Tap to close"))
  }

  // MARK: - Viewer Content

  private var viewerContent: some View {
    ZStack {
      // Background
      configuration.backgroundColor
        .opacity(backgroundOpacity)
        .ignoresSafeArea()
        .onTapGesture {
          dismiss()
        }

      // Image pages
      if isSingleImage {
        singleImageView
      } else {
        multipleImagesView
      }

      // Overlay
      overlay(currentIndex)
        .opacity(showsControls ? 1 : 0)

      // Page indicator (only for multiple images)
      if !isSingleImage && imageSources.count > 1 {
        pageIndicator
      }
    }
    .overlay(alignment: closeButtonAlignment) {
      if configuration.closeButton.isVisible {
        closeButton
      }
    }
  }

  // MARK: - Single Image View

  private var singleImageView: some View {
    ImagePageView(
      imageSource: imageSources[0],
      sourceFrame: sourceFrames?.first,
      configuration: configuration,
      isCurrentPage: true,
      transitionState: $transitionState,
      hasAppeared: $hasAppeared,
      onDismiss: dismiss
    )
  }

  // MARK: - Multiple Images View

  private var multipleImagesView: some View {
    TabView(selection: $currentIndex) {
      ForEach(Array(imageSources.enumerated()), id: \.offset) { index, source in
        ImagePageView(
          imageSource: source,
          sourceFrame: sourceFrameForIndex(index),
          configuration: configuration,
          isCurrentPage: index == currentIndex,
          transitionState: $transitionState,
          hasAppeared: $hasAppeared,
          onDismiss: dismiss
        )
        .tag(index)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text("Image gallery"))
    .accessibilityValue(Text("Page \(currentIndex + 1) of \(imageSources.count)"))
  }

  // MARK: - Close Button

  private var closeButtonAlignment: Alignment {
    switch configuration.closeButton.position {
    case .topLeading:
      return .topLeading
    case .topTrailing:
      return .topTrailing
    }
  }

  private var closeButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "xmark.circle.fill")
        .font(.title)
        .symbolRenderingMode(.palette)
        .foregroundStyle(.white, .black.opacity(0.5))
        .frame(width: 44, height: 44)
    }
    .padding(8)
    .padding(.top, SafeAreaHelper.topInset)
    .padding(
      configuration.closeButton.position == .topLeading ? .leading : .trailing,
      8
    )
    .opacity(showsControls ? 1.0 : 0.0)
    .accessibilityLabel(Text("Close"))
    .accessibilityHint(Text("Closes the image viewer"))
  }

  // MARK: - Page Indicator

  @ViewBuilder
  private var pageIndicator: some View {
    switch configuration.pageIndicator.style {
    case .dots:
      dotsIndicator
    case .text:
      textIndicator
    case .none:
      EmptyView()
    }
  }

  private var dotsIndicator: some View {
    VStack {
      Spacer()
      HStack(spacing: 6) {
        ForEach(0..<imageSources.count, id: \.self) { index in
          Circle()
            .fill(
              index == currentIndex
                ? configuration.pageIndicator.currentPageColor
                : configuration.pageIndicator.pageColor
            )
            .frame(width: 6, height: 6)
        }
      }
      .padding(.bottom, 50)
    }
    .opacity(showsControls ? 1 : 0)
    .accessibilityHidden(true)
  }

  private var textIndicator: some View {
    VStack {
      Spacer()
      Text("\(currentIndex + 1) / \(imageSources.count)")
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(configuration.pageIndicator.currentPageColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.5), in: Capsule())
        .padding(.bottom, 50)
    }
    .opacity(showsControls ? 1 : 0)
    .accessibilityHidden(true)
  }

  // MARK: - Helpers

  private func sourceFrameForIndex(_ index: Int) -> CGRect? {
    guard let frames = sourceFrames, index < frames.count else {
      return nil
    }
    return frames[index]
  }

  private func dismiss() {
    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
      transitionState = .dismissing
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      isPresented = false
      configuration.onDismiss?()
    }
  }
}

// MARK: - Image Page View

/// Individual page with image loading support.
struct ImagePageView: View {
  let imageSource: ImageSource
  let sourceFrame: CGRect?
  let configuration: ImageViewerConfiguration
  let isCurrentPage: Bool
  @Binding var transitionState: ImageTransitionState
  @Binding var hasAppeared: Bool
  let onDismiss: () -> Void

  @State private var loadedImage: UIImage?
  @State private var isLoading = false
  @State private var loadError: Error?

  private var displayImage: UIImage? {
    switch imageSource {
    case .image(let image):
      return image
    case .url, .async:
      return loadedImage ?? imageSource.placeholder
    }
  }

  var body: some View {
    Group {
      if let image = displayImage {
        ZoomableImageView(
          image: image,
          sourceFrame: sourceFrame,
          configuration: configuration,
          isCurrentPage: isCurrentPage,
          transitionState: $transitionState,
          hasAppeared: $hasAppeared,
          onDismiss: onDismiss
        )
      } else if isLoading {
        ProgressView()
          .tint(.white)
      } else if loadError != nil {
        errorView
      }
    }
    .task {
      await loadImageIfNeeded()
    }
  }

  private var errorView: some View {
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

  private func loadImageIfNeeded() async {
    switch imageSource {
    case .image:
      break

    case .url(let url, _):
      await loadImage(from: url)

    case .async(let loader, _):
      await loadImage(using: loader)
    }
  }

  private func loadImage(from url: URL) async {
    isLoading = true
    defer { isLoading = false }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      if let image = UIImage(data: data) {
        loadedImage = image
      } else {
        loadError = ImageLoadingError.invalidData
      }
    } catch {
      loadError = error
    }
  }

  private func loadImage(using loader: @Sendable () async throws -> UIImage) async {
    isLoading = true
    defer { isLoading = false }

    do {
      loadedImage = try await loader()
    } catch {
      loadError = error
    }
  }
}

// MARK: - Safe Area Helper

@MainActor
enum SafeAreaHelper {
  static var topInset: CGFloat {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?
      .windows
      .first?
      .safeAreaInsets.top ?? 0
  }
}

// MARK: - Image Loading Error

enum ImageLoadingError: Error, LocalizedError {
  case invalidData

  var errorDescription: String? {
    switch self {
    case .invalidData:
      return "The image data is invalid or corrupted."
    }
  }
}

// MARK: - Convenience Init

extension ImageViewerContent where Overlay == EmptyView {
  init(
    imageSources: [ImageSource],
    initialIndex: Int = 0,
    sourceFrames: [CGRect]? = nil,
    isPresented: Binding<Bool>,
    configuration: ImageViewerConfiguration
  ) {
    self.init(
      imageSources: imageSources,
      initialIndex: initialIndex,
      sourceFrames: sourceFrames,
      isPresented: isPresented,
      configuration: configuration,
      overlay: { _ in EmptyView() }
    )
  }
}
