import Testing
@testable import ImageViewer

@Suite("ImageViewerIndex.clamp")
struct ImageViewerIndexTests {

  @Test("Index within range is unchanged")
  func withinRange() {
    #expect(ImageViewerIndex.clamp(0, count: 3) == 0)
    #expect(ImageViewerIndex.clamp(1, count: 3) == 1)
    #expect(ImageViewerIndex.clamp(2, count: 3) == 2)
  }

  @Test("Index above range is clamped to last valid index")
  func aboveRange() {
    #expect(ImageViewerIndex.clamp(5, count: 3) == 2)
    #expect(ImageViewerIndex.clamp(100, count: 1) == 0)
  }

  @Test("Negative index is clamped to zero")
  func negativeIndex() {
    #expect(ImageViewerIndex.clamp(-1, count: 3) == 0)
    #expect(ImageViewerIndex.clamp(-100, count: 3) == 0)
  }

  @Test("Empty collection clamps to zero without crashing")
  func emptyCollection() {
    #expect(ImageViewerIndex.clamp(0, count: 0) == 0)
    #expect(ImageViewerIndex.clamp(5, count: 0) == 0)
    #expect(ImageViewerIndex.clamp(-1, count: 0) == 0)
  }
}
