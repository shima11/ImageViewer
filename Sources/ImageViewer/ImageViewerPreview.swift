import SwiftUI

// MARK: - Single Image Previews

#Preview("Single Image") {
  SingleImagePreview()
}

#Preview("With Overlay") {
  SingleImageWithOverlayPreview()
}

// MARK: - Gallery Previews

#Preview("Gallery Grid") {
  GalleryGridPreview()
}

#Preview("Gallery with Captions") {
  GalleryWithCaptionsPreview()
}

#Preview("Text Page Indicator") {
  TextPageIndicatorPreview()
}

#Preview("Custom UI") {
  CustomUIPreview()
}

#Preview("Empty Gallery") {
  EmptyGalleryPreview()
}

#Preview("Fill Mode Transition") {
  FillModeTransitionPreview()
}

// MARK: - Single Image Preview Views

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
        sourceFrame: sourceFrame
      ) { context in
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

// MARK: - Gallery Preview Views

private struct GalleryGridPreview: View {
  @State private var isPresented = false
  @State private var selectedIndex = 0
  @State private var sourceFrames: [CGRect] = Array(repeating: .zero, count: 6)

  private let images = PreviewImageGenerator.sampleImages
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
              .contentShape(Rectangle())
              .opacity(isPresented && selectedIndex == index ? 0 : 1)
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
      .imageViewer(
        isPresented: $isPresented,
        images: images,
        initialIndex: selectedIndex,
        sourceFrames: sourceFrames,
        sourceContentMode: .fill
      )
    }
  }
}

private struct GalleryWithCaptionsPreview: View {
  @State private var isPresented = false
  @State private var selectedIndex = 0
  @State private var sourceFrames: [CGRect] = Array(repeating: .zero, count: 4)

  private let images = PreviewImageGenerator.landscapeImages
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
                .contentShape(Rectangle())
                .opacity(isPresented && selectedIndex == index ? 0 : 1)
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
      .imageViewer(
        isPresented: $isPresented,
        images: images,
        initialIndex: selectedIndex,
        sourceFrames: sourceFrames,
        sourceContentMode: .fill
      ) { context in
        VStack {
          Spacer()
          Text(captions[context.currentIndex])
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

  private let images = PreviewImageGenerator.sampleImages

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
      .imageViewer(
        isPresented: $isPresented,
        sources: images.map { .image($0) },
        initialIndex: selectedIndex,
        overlay: { _ in EmptyView() },
        closeButton: { DefaultCloseButton(dismiss: $0) },
        pageIndicator: { currentIndex, totalCount in
          // Custom text-style page indicator
          Text("\(currentIndex + 1) / \(totalCount)")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.5), in: Capsule())
        },
        emptyContent: { DefaultEmptyView(dismiss: $0) },
        loadingContent: { DefaultLoadingView() },
        errorContent: { DefaultErrorView(error: $0) }
      )
    }
  }
}

private struct CustomUIPreview: View {
  @State private var isPresented = false
  @State private var selectedIndex = 0

  private let images = PreviewImageGenerator.sampleImages

  var body: some View {
    NavigationStack {
      VStack {
        Text("Fully customized UI")
          .foregroundStyle(.secondary)
          .padding()

        Button("Open Gallery") {
          isPresented = true
        }
        .buttonStyle(.borderedProminent)

        Spacer()
      }
      .navigationTitle("Custom UI")
      .imageViewer(
        isPresented: $isPresented,
        sources: images.map { .image($0) },
        initialIndex: selectedIndex,
        overlay: { context in
          // Custom overlay with share button
          VStack {
            HStack {
              Spacer()
              Button {
                // Share action
              } label: {
                Image(systemName: "square.and.arrow.up")
                  .font(.title2)
                  .foregroundStyle(.white)
                  .frame(width: 44, height: 44)
              }
              .padding(.trailing, 60)
              .padding(.top, 50)
            }
            Spacer()
          }
        },
        closeButton: { dismiss in
          // Custom close button
          Button(action: dismiss) {
            Text("Done")
              .fontWeight(.semibold)
              .foregroundStyle(.white)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(.ultraThinMaterial, in: Capsule())
          }
        },
        pageIndicator: { currentIndex, totalCount in
          // Custom numbered indicator
          HStack(spacing: 4) {
            ForEach(0..<totalCount, id: \.self) { index in
              if index == currentIndex {
                Text("\(index + 1)")
                  .font(.caption.bold())
                  .foregroundStyle(.black)
                  .frame(width: 20, height: 20)
                  .background(.white, in: Circle())
              } else {
                Circle()
                  .fill(.white.opacity(0.5))
                  .frame(width: 8, height: 8)
              }
            }
          }
        },
        emptyContent: { dismiss in
          // Custom empty state
          VStack(spacing: 20) {
            Image(systemName: "photo.stack")
              .font(.system(size: 60))
              .foregroundStyle(.white.opacity(0.4))

            Text("No Photos")
              .font(.title2.bold())
              .foregroundStyle(.white)

            Button("Close", action: dismiss)
              .buttonStyle(.bordered)
              .tint(.white)
          }
        },
        loadingContent: {
          // Custom loading indicator
          VStack(spacing: 12) {
            ProgressView()
              .scaleEffect(1.5)
              .tint(.white)
            Text("Loading...")
              .foregroundStyle(.white.opacity(0.8))
          }
        },
        errorContent: { error in
          // Custom error view
          VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
              .font(.system(size: 50))
              .foregroundStyle(.red.opacity(0.8))

            Text("Failed to Load")
              .font(.headline)
              .foregroundStyle(.white)

            Text(error.localizedDescription)
              .font(.caption)
              .foregroundStyle(.white.opacity(0.6))
              .multilineTextAlignment(.center)
          }
          .padding()
        }
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
      .imageViewer(
        isPresented: $isPresented,
        images: [],
        initialIndex: 0
      )
    }
  }
}

private struct FillModeTransitionPreview: View {
  @State private var isPresented = false
  @State private var selectedIndex = 0
  @State private var sourceFrames: [CGRect] = Array(repeating: .zero, count: 4)

  // Tall images to demonstrate fill mode cropping
  private let images: [UIImage] = {
    let colorPairs: [(UIColor, UIColor)] = [
      (.systemPurple, .systemBlue),
      (.systemRed, .systemOrange),
      (.systemTeal, .systemGreen),
      (.systemIndigo, .systemPink),
    ]
    return colorPairs.enumerated().map { index, colors in
      PreviewImageGenerator.gradient(
        colors: colors,
        size: CGSize(width: 600, height: 1200),  // Tall aspect ratio (1:2)
        text: "\(index + 1)"
      )
    }
  }()

  private let columns = [GridItem(.flexible()), GridItem(.flexible())]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          Text("Thumbnails use .fill + clip")
            .font(.headline)

          Text("The transition starts from the cropped view and expands to show the full image")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

          LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
              Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 160, height: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .opacity(isPresented && selectedIndex == index ? 0 : 1)
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

          Text("Image aspect: 1:2 (tall)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical)
      }
      .navigationTitle("Fill Mode")
      .imageViewer(
        isPresented: $isPresented,
        images: images,
        initialIndex: selectedIndex,
        sourceFrames: sourceFrames,
        sourceContentMode: .fill
      )
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
      gradient(colors: colors, size: CGSize(width: 800, height: 600), text: "\(index + 1)")
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
      gradient(colors: colors, size: CGSize(width: 1200, height: 800), text: nil)
    }
  }()
}
