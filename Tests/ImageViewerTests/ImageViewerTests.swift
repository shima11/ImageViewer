import Testing
@testable import ImageViewer

@Suite("ImageViewer Tests")
struct ImageViewerTests {

  @Test("Default configuration has expected values")
  func defaultConfiguration() {
    let config = ImageViewerConfiguration.default

    #expect(config.maxScale == 5.0)
    #expect(config.doubleTapScale == 3.0)
    #expect(config.dismissThreshold == 100)
    #expect(config.dismissVelocityThreshold == 500)
  }

  @Test("Custom configuration preserves values")
  func customConfiguration() {
    let config = ImageViewerConfiguration(
      maxScale: 10.0,
      doubleTapScale: 2.0,
      dismissThreshold: 150,
      dismissVelocityThreshold: 600
    )

    #expect(config.maxScale == 10.0)
    #expect(config.doubleTapScale == 2.0)
    #expect(config.dismissThreshold == 150)
    #expect(config.dismissVelocityThreshold == 600)
  }
}
