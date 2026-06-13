import Testing
import UIKit
@testable import ImageViewer

@Suite("ImageSource.placeholder")
struct ImageSourceTests {

  private func makeImage() -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
    return renderer.image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
  }

  @Test("Pre-loaded image source has no placeholder")
  func imageSourceHasNoPlaceholder() {
    let source = ImageSource.image(makeImage())
    #expect(source.placeholder == nil)
  }

  @Test("Async source exposes its placeholder")
  func asyncSourceExposesPlaceholder() {
    let placeholder = makeImage()
    let source = ImageSource.async({ self.makeImage() }, placeholder: placeholder)
    #expect(source.placeholder === placeholder)
  }

  @Test("Async source without placeholder returns nil")
  func asyncSourceWithoutPlaceholder() {
    let source = ImageSource.async({ self.makeImage() }, placeholder: nil)
    #expect(source.placeholder == nil)
  }

  @Test("URL source exposes its placeholder")
  func urlSourceExposesPlaceholder() {
    let placeholder = makeImage()
    let source = ImageSource.url(URL(string: "https://example.com/a.jpg")!, placeholder: placeholder)
    #expect(source.placeholder === placeholder)
  }

  @Test("URL source without placeholder returns nil")
  func urlSourceWithoutPlaceholder() {
    let source = ImageSource.url(URL(string: "https://example.com/a.jpg")!)
    #expect(source.placeholder == nil)
  }

  @Test("Pre-loaded image source exposes a sync image")
  func imageSourceHasSyncImage() {
    let image = makeImage()
    #expect(ImageSource.image(image).syncImage === image)
  }

  @Test("Async and URL sources have no sync image")
  func asyncSourcesHaveNoSyncImage() {
    #expect(ImageSource.async({ self.makeImage() }, placeholder: nil).syncImage == nil)
    #expect(ImageSource.url(URL(string: "https://example.com/a.jpg")!).syncImage == nil)
  }

  @Test("Only sync images are preloaded into the loaded-images map")
  func onlySyncImagesArePreloaded() {
    let img0 = makeImage()
    let img2 = makeImage()
    let sources: [ImageSource] = [
      .image(img0),
      .async({ self.makeImage() }, placeholder: nil),
      .image(img2),
    ]

    // Mirrors ImageViewerController.preloadAllSyncImages.
    var loaded: [Int: UIImage] = [:]
    for (index, source) in sources.enumerated() {
      if let image = source.syncImage {
        loaded[index] = image
      }
    }

    #expect(loaded.count == 2)
    #expect(loaded[0] === img0)
    #expect(loaded[1] == nil)
    #expect(loaded[2] === img2)
  }
}

@Suite("ImageViewerConfiguration")
struct ImageViewerConfigurationTests {

  @Test("HDR is disabled by default")
  func hdrDisabledByDefault() {
    #expect(ImageViewerConfiguration().enableHDR == false)
    #expect(ImageViewerConfiguration.default.enableHDR == false)
  }

  @Test("HDR can be enabled")
  func hdrCanBeEnabled() {
    #expect(ImageViewerConfiguration(enableHDR: true).enableHDR == true)
  }
}
