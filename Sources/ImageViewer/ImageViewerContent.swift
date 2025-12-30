import SwiftUI

// MARK: - Image Viewer Content

/// The main image viewer component supporting single and multiple images.
struct ImageViewerContent<
  Overlay: View,
  CloseButton: View,
  PageIndicator: View,
  EmptyContent: View,
  LoadingContent: View,
  ErrorContent: View
>: View {
  let imageSources: [ImageSource]
  let initialIndex: Int
  let sourceFrames: [CGRect]?
  let sourceContentMode: ContentMode
  @Binding var isPresented: Bool
  let configuration: ImageViewerConfiguration
  @ViewBuilder var overlay: (ImageViewerContext) -> Overlay
  @ViewBuilder var closeButton: (_ dismiss: @escaping () -> Void) -> CloseButton
  @ViewBuilder var pageIndicator: (_ currentIndex: Int, _ totalCount: Int) -> PageIndicator
  @ViewBuilder var emptyContent: (_ dismiss: @escaping () -> Void) -> EmptyContent
  @ViewBuilder var loadingContent: () -> LoadingContent
  @ViewBuilder var errorContent: (Error) -> ErrorContent

  // MARK: - State

  @State private var currentIndex: Int
  @State private var transitionState: ImageTransitionState = .appearing
  @State private var hasAppeared = false
  @State private var dragOffset: CGSize = .zero
  @State private var dismissProgress: CGFloat = 0

  // MARK: - Init

  init(
    imageSources: [ImageSource],
    initialIndex: Int,
    sourceFrames: [CGRect]?,
    sourceContentMode: ContentMode,
    isPresented: Binding<Bool>,
    configuration: ImageViewerConfiguration,
    @ViewBuilder overlay: @escaping (ImageViewerContext) -> Overlay,
    @ViewBuilder closeButton: @escaping (_ dismiss: @escaping () -> Void) -> CloseButton,
    @ViewBuilder pageIndicator: @escaping (_ currentIndex: Int, _ totalCount: Int) -> PageIndicator,
    @ViewBuilder emptyContent: @escaping (_ dismiss: @escaping () -> Void) -> EmptyContent,
    @ViewBuilder loadingContent: @escaping () -> LoadingContent,
    @ViewBuilder errorContent: @escaping (Error) -> ErrorContent
  ) {
    self.imageSources = imageSources
    let validIndex = max(0, min(initialIndex, max(0, imageSources.count - 1)))
    self.initialIndex = validIndex
    self.sourceFrames = sourceFrames
    self.sourceContentMode = sourceContentMode
    self._isPresented = isPresented
    self.configuration = configuration
    self.overlay = overlay
    self.closeButton = closeButton
    self.pageIndicator = pageIndicator
    self.emptyContent = emptyContent
    self.loadingContent = loadingContent
    self.errorContent = errorContent
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
      return 1.0 - Double(dismissProgress) * 0.8
    }
  }

  private var context: ImageViewerContext {
    ImageViewerContext(
      currentIndex: currentIndex,
      totalCount: imageSources.count,
      dismiss: dismiss
    )
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

      emptyContent(dismiss)
    }
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
      overlay(context)
        .opacity(showsControls ? 1 : 0)

      // Close button
      VStack {
        HStack {
          closeButton(dismiss)
            .padding(8)
            .padding(.top, SafeAreaHelper.topInset)
          Spacer()
        }
        Spacer()
      }
      .opacity(showsControls ? 1 : 0)

      // Page indicator (only for multiple images)
      if !isSingleImage && imageSources.count > 1 {
        VStack {
          Spacer()
          pageIndicator(currentIndex, imageSources.count)
            .padding(.bottom, 50)
        }
        .opacity(showsControls ? 1 : 0)
      }
    }
  }

  // MARK: - Single Image View

  private var singleImageView: some View {
    ImagePageView(
      imageSource: imageSources[0],
      sourceFrame: sourceFrames?.first,
      sourceContentMode: sourceContentMode,
      configuration: configuration,
      isCurrentPage: true,
      transitionState: $transitionState,
      hasAppeared: $hasAppeared,
      loadingContent: loadingContent,
      errorContent: errorContent,
      onDismiss: dismiss
    )
  }

  // MARK: - Multiple Images View

  private var multipleImagesView: some View {
    MultiImageViewer(
      imageSources: imageSources,
      sourceFrames: sourceFrames,
      sourceContentMode: sourceContentMode,
      configuration: configuration,
      currentIndex: $currentIndex,
      transitionState: $transitionState,
      hasAppeared: $hasAppeared,
      dragOffset: $dragOffset,
      dismissProgress: $dismissProgress,
      loadingContent: loadingContent,
      errorContent: errorContent,
      onDismiss: dismiss
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text("Image gallery"))
    .accessibilityValue(Text("Page \(currentIndex + 1) of \(imageSources.count)"))
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
struct ImagePageView<LoadingContent: View, ErrorContent: View>: View {
  let imageSource: ImageSource
  let sourceFrame: CGRect?
  let sourceContentMode: ContentMode
  let configuration: ImageViewerConfiguration
  let isCurrentPage: Bool
  @Binding var transitionState: ImageTransitionState
  @Binding var hasAppeared: Bool
  @ViewBuilder var loadingContent: () -> LoadingContent
  @ViewBuilder var errorContent: (Error) -> ErrorContent
  let onDismiss: () -> Void

  @State private var loadedImage: UIImage?
  @State private var isLoading = false
  @State private var loadError: Error?

  private var displayImage: UIImage? {
    switch imageSource {
    case .image(let image):
      return image
    case .async:
      return loadedImage ?? imageSource.placeholder
    }
  }

  var body: some View {
    Group {
      if let image = displayImage {
        ZoomableImageView(
          image: image,
          sourceFrame: sourceFrame,
          sourceContentMode: sourceContentMode,
          configuration: configuration,
          isCurrentPage: isCurrentPage,
          transitionState: $transitionState,
          hasAppeared: $hasAppeared,
          onDismiss: onDismiss
        )
      } else if isLoading {
        loadingContent()
      } else if let error = loadError {
        errorContent(error)
      }
    }
    .task {
      await loadImageIfNeeded()
    }
  }

  private func loadImageIfNeeded() async {
    switch imageSource {
    case .image:
      break

    case .async(let loader, _):
      isLoading = true
      defer { isLoading = false }

      do {
        loadedImage = try await loader()
      } catch {
        loadError = error
      }
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
