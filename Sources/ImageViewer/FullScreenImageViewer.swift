import SwiftUI

// MARK: - Full Screen Image Viewer

/// A full-screen image viewer with zoom and interactive dismiss support.
struct FullScreenImageViewer<Overlay: View>: View {
  let imageSource: ImageSource
  let sourceFrame: CGRect?
  @Binding var isPresented: Bool
  let configuration: ImageViewerConfiguration
  let overlay: () -> Overlay

  // MARK: - State

  @State private var transitionState: ImageTransitionState = .appearing
  @State private var hasAppeared = false
  @State private var loadedImage: UIImage?
  @State private var isLoading = false
  @State private var loadError: Error?

  // MARK: - Init

  init(
    imageSource: ImageSource,
    sourceFrame: CGRect?,
    isPresented: Binding<Bool>,
    configuration: ImageViewerConfiguration,
    @ViewBuilder overlay: @escaping () -> Overlay
  ) {
    self.imageSource = imageSource
    self.sourceFrame = sourceFrame
    self._isPresented = isPresented
    self.configuration = configuration
    self.overlay = overlay
  }

  // MARK: - Computed Properties

  private var displayImage: UIImage? {
    switch imageSource {
    case .image(let image):
      return image
    case .url, .async:
      return loadedImage ?? imageSource.placeholder
    }
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

  private var showsControls: Bool {
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
            dismiss()
          }

        // Content
        if let image = displayImage {
          ZoomableImageView(
            image: image,
            sourceFrame: sourceFrame,
            configuration: configuration,
            transitionState: $transitionState,
            hasAppeared: $hasAppeared,
            onDismiss: dismiss
          )
        } else if isLoading {
          ProgressView()
            .tint(.white)
        } else if loadError != nil {
          errorView
        }

        // Overlay
        overlay()
          .opacity(showsControls ? 1 : 0)
      }
    }
    .overlay(alignment: closeButtonAlignment) {
      if configuration.closeButton.isVisible {
        closeButton
      }
    }
    .ignoresSafeArea()
    .statusBarHidden()
    .accessibilityAction(.escape) {
      dismiss()
    }
    .task {
      await loadImageIfNeeded()
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
    .accessibilityHint(Text("Closes the image viewer"))
  }

  private var safeAreaInsets: UIEdgeInsets {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?
      .windows
      .first?
      .safeAreaInsets ?? .zero
  }

  // MARK: - Error View

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

  // MARK: - Actions

  private func dismiss() {
    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
      transitionState = .dismissing
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      isPresented = false
      configuration.onDismiss?()
    }
  }

  // MARK: - Image Loading

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

extension FullScreenImageViewer where Overlay == EmptyView {
  init(
    imageSource: ImageSource,
    sourceFrame: CGRect?,
    isPresented: Binding<Bool>,
    configuration: ImageViewerConfiguration
  ) {
    self.init(
      imageSource: imageSource,
      sourceFrame: sourceFrame,
      isPresented: isPresented,
      configuration: configuration,
      overlay: { EmptyView() }
    )
  }

  /// Legacy initializer for UIImage.
  init(
    image: UIImage,
    sourceFrame: CGRect?,
    isPresented: Binding<Bool>,
    configuration: ImageViewerConfiguration
  ) {
    self.init(
      imageSource: .image(image),
      sourceFrame: sourceFrame,
      isPresented: isPresented,
      configuration: configuration
    )
  }
}

// MARK: - Error

enum ImageLoadingError: Error, LocalizedError {
  case invalidData

  var errorDescription: String? {
    switch self {
    case .invalidData:
      return "The image data is invalid or corrupted."
    }
  }
}

// MARK: - Preview

#Preview("Single Image") {
  SingleImagePreview()
}

#Preview("With Overlay") {
  SingleImageWithOverlayPreview()
}

private struct SingleImagePreview: View {
  @State private var isPresented = false
  @State private var sourceFrame: CGRect = .zero

  private let sampleImage = PreviewImageGenerator.gradient(
    colors: (.systemBlue, .systemPurple),
    size: CGSize(width: 800, height: 600)
  )

  var body: some View {
    NavigationStack {
      VStack {
        Text("Tap the image to open viewer")
          .foregroundStyle(.secondary)
          .padding()

        Image(uiImage: sampleImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 200, height: 150)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .shadow(radius: 4)
          .opacity(isPresented ? 0 : 1)
          .readFrame { frame in
            sourceFrame = frame
          }
          .onTapGesture {
            isPresented = true
          }

        Spacer()
      }
      .navigationTitle("ImageViewer")
      .imageViewer(
        isPresented: $isPresented,
        image: sampleImage,
        sourceFrame: sourceFrame
      )
    }
  }
}

private struct SingleImageWithOverlayPreview: View {
  @State private var isPresented = false
  @State private var sourceFrame: CGRect = .zero

  private let sampleImage = PreviewImageGenerator.gradient(
    colors: (.systemOrange, .systemRed),
    size: CGSize(width: 800, height: 1200)
  )

  var body: some View {
    NavigationStack {
      VStack {
        Text("Image with caption overlay")
          .foregroundStyle(.secondary)
          .padding()

        Image(uiImage: sampleImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 150, height: 225)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .shadow(radius: 4)
          .opacity(isPresented ? 0 : 1)
          .readFrame { frame in
            sourceFrame = frame
          }
          .onTapGesture {
            isPresented = true
          }

        Spacer()
      }
      .navigationTitle("With Overlay")
      .imageViewer(
        isPresented: $isPresented,
        source: .image(sampleImage),
        sourceFrame: sourceFrame,
        configuration: ImageViewerConfiguration(
          closeButton: .init(position: .topLeading)
        )
      ) {
        VStack {
          Spacer()
          Text("Beautiful Sunset")
            .font(.headline)
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.5))
        }
      }
    }
  }
}

// MARK: - Preview Image Generator

enum PreviewImageGenerator {
  static func gradient(
    colors: (UIColor, UIColor),
    size: CGSize,
    text: String? = nil
  ) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [colors.0.cgColor, colors.1.cgColor] as CFArray,
        locations: [0, 1]
      )!
      context.cgContext.drawLinearGradient(
        gradient,
        start: .zero,
        end: CGPoint(x: size.width, y: size.height),
        options: []
      )

      if let text {
        let nsText = text as NSString
        let attributes: [NSAttributedString.Key: Any] = [
          .font: UIFont.systemFont(ofSize: min(size.width, size.height) * 0.3, weight: .bold),
          .foregroundColor: UIColor.white.withAlphaComponent(0.5),
        ]
        let textSize = nsText.size(withAttributes: attributes)
        let textRect = CGRect(
          x: (size.width - textSize.width) / 2,
          y: (size.height - textSize.height) / 2,
          width: textSize.width,
          height: textSize.height
        )
        nsText.draw(in: textRect, withAttributes: attributes)
      }
    }
  }
}
