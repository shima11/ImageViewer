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

#Preview("Empty Gallery") {
  EmptyGalleryPreview()
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
        sourceFrames: sourceFrames
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
      .imageViewer(
        isPresented: $isPresented,
        images: [],
        initialIndex: 0
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
