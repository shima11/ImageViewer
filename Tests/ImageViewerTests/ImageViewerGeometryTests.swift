import Testing
import CoreGraphics
@testable import ImageViewer

@Suite("ImageViewerGeometry.aspectFitFrame")
struct AspectFitFrameTests {
  private let bounds = CGRect(x: 0, y: 0, width: 100, height: 200)

  @Test("Wide image fits to width and centers vertically")
  func wideImage() {
    // 2:1 image in a 100x200 bounds -> 100 wide, 50 tall, centered.
    let frame = ImageViewerGeometry.aspectFitFrame(imageSize: CGSize(width: 200, height: 100), in: bounds)
    #expect(frame.width == 100)
    #expect(frame.height == 50)
    #expect(frame.minX == 0)
    #expect(frame.minY == 75)
  }

  @Test("Tall image fits to height and centers horizontally")
  func tallImage() {
    // 1:2 image in a 100x200 bounds -> 100 tall? No: fits to height 200, width 100.
    let frame = ImageViewerGeometry.aspectFitFrame(imageSize: CGSize(width: 100, height: 200), in: bounds)
    #expect(frame.width == 100)
    #expect(frame.height == 200)
    #expect(frame.minX == 0)
    #expect(frame.minY == 0)
  }

  @Test("Square image in tall bounds fits to width")
  func squareImage() {
    let frame = ImageViewerGeometry.aspectFitFrame(imageSize: CGSize(width: 50, height: 50), in: bounds)
    #expect(frame.width == 100)
    #expect(frame.height == 100)
    #expect(frame.minY == 50)
  }

  @Test("Zero-area image returns the bounds unchanged")
  func zeroAreaImage() {
    #expect(ImageViewerGeometry.aspectFitFrame(imageSize: .zero, in: bounds) == bounds)
    #expect(ImageViewerGeometry.aspectFitFrame(imageSize: CGSize(width: 0, height: 100), in: bounds) == bounds)
  }

  @Test("Respects a non-zero bounds origin")
  func nonZeroOrigin() {
    let offset = CGRect(x: 10, y: 20, width: 100, height: 200)
    let frame = ImageViewerGeometry.aspectFitFrame(imageSize: CGSize(width: 200, height: 100), in: offset)
    #expect(frame.minX == 10)
    #expect(frame.minY == 95) // 20 + (200 - 50)/2
  }
}

@Suite("ImageViewerGeometry.interactiveFrame")
struct InteractiveFrameTests {
  // 100x200 fullscreen frame, center at (50, 100).
  private let finalFrame = CGRect(x: 0, y: 0, width: 100, height: 200)

  @Test("Progress zero with no translation is the identity")
  func progressZero() {
    let frame = ImageViewerGeometry.interactiveFrame(
      finalFrame: finalFrame, translation: .zero, progress: 0
    )
    #expect(frame == finalFrame)
  }

  @Test("Translation only moves the frame without resizing")
  func translationOnly() {
    let frame = ImageViewerGeometry.interactiveFrame(
      finalFrame: finalFrame, translation: CGPoint(x: 0, y: 100), progress: 0
    )
    #expect(frame.size == finalFrame.size)
    #expect(frame.minX == 0)
    #expect(frame.minY == 100)
  }

  @Test("Full progress shrinks to minScale around the center")
  func fullProgress() {
    let frame = ImageViewerGeometry.interactiveFrame(
      finalFrame: finalFrame, translation: .zero, progress: 1, minScale: 0.5
    )
    // 0.5 scale of 100x200 = 50x100, recentered on (50, 100).
    #expect(frame.width == 50)
    #expect(frame.height == 100)
    #expect(frame.midX == 50)
    #expect(frame.midY == 100)
  }

  @Test("Downward drag moves the image down, not toward a source frame")
  func downwardDragFollowsFinger() {
    // Regression for the old double-application: with a positive translation.y
    // the image center must move down, never get pulled up toward sourceFrame.
    let frame = ImageViewerGeometry.interactiveFrame(
      finalFrame: finalFrame, translation: CGPoint(x: 0, y: 60), progress: 0.2
    )
    #expect(frame.midY > finalFrame.midY)
  }

  @Test("Horizontal translation moves the center sideways")
  func horizontalTranslation() {
    let frame = ImageViewerGeometry.interactiveFrame(
      finalFrame: finalFrame, translation: CGPoint(x: 30, y: 0), progress: 0.2
    )
    #expect(frame.midX == finalFrame.midX + 30)
  }

  @Test("Size shrinks monotonically as progress increases")
  func monotonicShrink() {
    let a = ImageViewerGeometry.interactiveFrame(finalFrame: finalFrame, translation: .zero, progress: 0.25)
    let b = ImageViewerGeometry.interactiveFrame(finalFrame: finalFrame, translation: .zero, progress: 0.75)
    #expect(b.width < a.width)
    #expect(b.height < a.height)
  }
}

@Suite("ImageViewerGeometry.keepRange")
struct KeepRangeTests {
  @Test("Default radius keeps +/- 2 around current")
  func defaultRadius() {
    let range = ImageViewerGeometry.keepRange(around: 5)
    #expect(range == 3...7)
  }

  @Test("Range includes out-of-bounds indices (caller filters)")
  func nearZero() {
    let range = ImageViewerGeometry.keepRange(around: 0)
    #expect(range.contains(-2))
    #expect(range.contains(2))
    #expect(!range.contains(3))
  }
}

@Suite("ImageViewerGeometry.sourceFrame")
struct SourceFrameTests {
  private let frames = [
    CGRect(x: 0, y: 0, width: 10, height: 10),
    CGRect(x: 10, y: 0, width: 10, height: 10),
  ]

  @Test("Returns the frame for a valid index")
  func validIndex() {
    #expect(ImageViewerGeometry.sourceFrame(from: frames, at: 1, hasRotated: false) == frames[1])
  }

  @Test("Out-of-range index returns nil")
  func outOfRange() {
    #expect(ImageViewerGeometry.sourceFrame(from: frames, at: 5, hasRotated: false) == nil)
    #expect(ImageViewerGeometry.sourceFrame(from: frames, at: -1, hasRotated: false) == nil)
  }

  @Test("Nil frames return nil")
  func nilFrames() {
    #expect(ImageViewerGeometry.sourceFrame(from: nil, at: 0, hasRotated: false) == nil)
  }

  @Test("After rotation, returns nil to fall back to slide-down")
  func rotatedFallsBack() {
    #expect(ImageViewerGeometry.sourceFrame(from: frames, at: 0, hasRotated: true) == nil)
    #expect(ImageViewerGeometry.sourceFrame(from: frames, at: 1, hasRotated: true) == nil)
  }
}
