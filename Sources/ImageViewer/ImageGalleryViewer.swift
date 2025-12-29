import SwiftUI

// MARK: - Image Gallery Viewer

/// A full-screen gallery viewer with swipe navigation between multiple images.
struct ImageGalleryViewer<Overlay: View>: View {
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
    // Validate initialIndex
    let validIndex = max(0, min(initialIndex, max(0, imageSources.count - 1)))
    self.initialIndex = validIndex
    self.sourceFrames = sourceFrames
    self._isPresented = isPresented
    self.configuration = configuration
    self.overlay = overlay
    self._currentIndex = State(initialValue: validIndex)
  }

  // MARK: - Computed Properties

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
        galleryContent
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

  // MARK: - Gallery Content

  private var galleryContent: some View {
    ZStack {
      // Background
      configuration.backgroundColor
        .opacity(backgroundOpacity)
        .ignoresSafeArea()
        .onTapGesture {
          dismiss()
        }

      // Image pages
      TabView(selection: $currentIndex) {
        ForEach(Array(imageSources.enumerated()), id: \.offset) { index, source in
          GalleryPageView(
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

      // Overlay
      overlay(currentIndex)
        .opacity(showsControls ? 1 : 0)

      // Page indicator
      if imageSources.count > 1 {
        pageIndicator
      }
    }
    .overlay(alignment: closeButtonAlignment) {
      if configuration.closeButton.isVisible {
        closeButton
      }
    }
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
    .padding(.top, safeAreaInsets.top)
    .padding(
      configuration.closeButton.position == .topLeading ? .leading : .trailing,
      8
    )
    .opacity(showsControls ? 1.0 : 0.0)
    .accessibilityLabel(Text("Close"))
    .accessibilityHint(Text("Closes the image gallery"))
  }

  private var safeAreaInsets: UIEdgeInsets {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?
      .windows
      .first?
      .safeAreaInsets ?? .zero
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

// MARK: - Gallery Page View

/// Individual page in the gallery with image loading support.
private struct GalleryPageView: View {
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

// MARK: - Convenience Init (No Overlay)

extension ImageGalleryViewer where Overlay == EmptyView {
  init(
    imageSources: [ImageSource],
    initialIndex: Int,
    sourceFrames: [CGRect]?,
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

  /// Legacy initializer for UIImage array.
  init(
    images: [UIImage],
    initialIndex: Int,
    sourceFrames: [CGRect]?,
    isPresented: Binding<Bool>,
    configuration: ImageViewerConfiguration
  ) {
    self.init(
      imageSources: images.map { .image($0) },
      initialIndex: initialIndex,
      sourceFrames: sourceFrames,
      isPresented: isPresented,
      configuration: configuration
    )
  }
}

// MARK: - Preview

#Preview("Gallery Grid") {
  GalleryGridPreview()
}

#Preview("Gallery with Captions") {
  GalleryWithCaptionsPreview()
}

#Preview("Text Page Indicator") {
  TextPageIndicatorPreview()
}

#Preview("Empty Gallery") {
  EmptyGalleryPreview()
}

private struct GalleryGridPreview: View {
  @State private var isPresented = false
  @State private var selectedIndex = 0
  @State private var sourceFrames: [CGRect] = Array(repeating: .zero, count: 6)

  private let images = GalleryPreviewData.sampleImages
  private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

  var body: some View {
    NavigationStack {
      ScrollView {
        Text("Tap any image to open gallery")
          .foregroundStyle(.secondary)
          .padding()

        LazyVGrid(columns: columns, spacing: 8) {
          ForEach(Array(images.enumerated()), id: \.offset) { index, image in
            Image(uiImage: image)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(height: 120)
              .clipped()
              .clipShape(RoundedRectangle(cornerRadius: 8))
              .readFrame { frame in
                if index < sourceFrames.count {
                  sourceFrames[index] = frame
                }
              }
              .onTapGesture {
                selectedIndex = index
                isPresented = true
              }
          }
        }
        .padding(.horizontal)
      }
      .navigationTitle("Photo Gallery")
      .imageGalleryViewer(
        isPresented: $isPresented,
        images: images,
        initialIndex: selectedIndex,
        sourceFrames: sourceFrames
      )
    }
  }
}

private struct GalleryWithCaptionsPreview: View {
  @State private var isPresented = false
  @State private var selectedIndex = 0
  @State private var sourceFrames: [CGRect] = Array(repeating: .zero, count: 4)

  private let images = GalleryPreviewData.landscapeImages
  private let captions = [
    "Mountain Sunrise",
    "Ocean Waves",
    "Forest Path",
    "Desert Dunes",
  ]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          Text("Gallery with caption overlay")
            .foregroundStyle(.secondary)

          ForEach(Array(images.enumerated()), id: \.offset) { index, image in
            VStack(alignment: .leading, spacing: 4) {
              Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .readFrame { frame in
                  if index < sourceFrames.count {
                    sourceFrames[index] = frame
                  }
                }
                .onTapGesture {
                  selectedIndex = index
                  isPresented = true
                }

              Text(captions[index])
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding()
      }
      .navigationTitle("With Captions")
      .imageGalleryViewer(
        isPresented: $isPresented,
        images: images,
        initialIndex: selectedIndex,
        sourceFrames: sourceFrames
      ) { currentIndex in
        VStack {
          Spacer()
          Text(captions[currentIndex])
            .font(.title3.bold())
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
              LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
              )
            )
        }
      }
    }
  }
}

private struct TextPageIndicatorPreview: View {
  @State private var isPresented = false
  @State private var selectedIndex = 0

  private let images = GalleryPreviewData.sampleImages

  var body: some View {
    NavigationStack {
      VStack {
        Text("Text style page indicator")
          .foregroundStyle(.secondary)
          .padding()

        Button("Open Gallery") {
          isPresented = true
        }
        .buttonStyle(.borderedProminent)

        Spacer()
      }
      .navigationTitle("Text Indicator")
      .imageGalleryViewer(
        isPresented: $isPresented,
        images: images,
        initialIndex: selectedIndex,
        configuration: ImageViewerConfiguration(
          pageIndicator: PageIndicatorConfiguration(style: .text)
        )
      )
    }
  }
}

private struct EmptyGalleryPreview: View {
  @State private var isPresented = false

  var body: some View {
    NavigationStack {
      VStack {
        Text("Empty gallery handling")
          .foregroundStyle(.secondary)
          .padding()

        Button("Open Empty Gallery") {
          isPresented = true
        }
        .buttonStyle(.borderedProminent)

        Spacer()
      }
      .navigationTitle("Empty Gallery")
      .imageGalleryViewer(
        isPresented: $isPresented,
        images: [],
        initialIndex: 0
      )
    }
  }
}

// MARK: - Preview Data

private enum GalleryPreviewData {
  static let sampleImages: [UIImage] = {
    let colorPairs: [(UIColor, UIColor)] = [
      (.systemBlue, .systemPurple),
      (.systemOrange, .systemRed),
      (.systemGreen, .systemTeal),
      (.systemPink, .systemIndigo),
      (.systemYellow, .systemOrange),
      (.systemCyan, .systemBlue),
    ]

    return colorPairs.enumerated().map { index, colors in
      PreviewImageGenerator.gradient(
        colors: colors,
        size: CGSize(width: 800, height: 600),
        text: "\(index + 1)"
      )
    }
  }()

  static let landscapeImages: [UIImage] = {
    let colorPairs: [(UIColor, UIColor)] = [
      (.systemOrange, .systemYellow),
      (.systemBlue, .systemCyan),
      (.systemGreen, .systemMint),
      (.systemBrown, .systemOrange),
    ]

    return colorPairs.map { colors in
      PreviewImageGenerator.gradient(
        colors: colors,
        size: CGSize(width: 1200, height: 800),
        text: nil
      )
    }
  }()
}
