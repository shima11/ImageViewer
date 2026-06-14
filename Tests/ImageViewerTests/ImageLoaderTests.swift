import Testing
import UIKit
@testable import ImageViewer

@MainActor
@Suite("ImageLoader")
struct ImageLoaderTests {

  private func makeImage() -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
    return renderer.image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
  }

  /// Loads `index` and suspends until the completion handler fires.
  private func load(_ loader: ImageLoader, at index: Int) async -> Result<UIImage, Error> {
    await withCheckedContinuation { continuation in
      loader.load(at: index) { result in
        continuation.resume(returning: result)
      }
    }
  }

  // MARK: - Preload

  @Test("Sync .image sources are preloaded as loaded")
  func syncSourcesPreloaded() {
    let img = makeImage()
    let other = makeImage()
    let loader = ImageLoader(imageSources: [.image(img), .async({ other }, placeholder: nil)])
    #expect(loader.image(at: 0) === img)
    #expect(loader.image(at: 1) == nil)
  }

  // MARK: - Index bounds

  @Test("Out-of-range index fails with indexOutOfRange")
  func outOfRangeFails() async {
    let loader = ImageLoader(imageSources: [.image(makeImage())])
    let result = await load(loader, at: 5)
    guard case .failure(let error) = result,
          case ImageViewerError.indexOutOfRange = error else {
      Issue.record("Expected indexOutOfRange, got \(result)")
      return
    }
  }

  // MARK: - Sync load

  @Test("Loading a preloaded .image source succeeds synchronously")
  func syncLoadSucceeds() async {
    let img = makeImage()
    let loader = ImageLoader(imageSources: [.image(img)])
    let result = await load(loader, at: 0)
    guard case .success(let loaded) = result else {
      Issue.record("Expected success, got \(result)")
      return
    }
    #expect(loaded === img)
  }

  // MARK: - Async load

  @Test("Async source loads and transitions to loaded")
  func asyncLoadSucceeds() async {
    let img = makeImage()
    let loader = ImageLoader(imageSources: [.async({ img }, placeholder: nil)])
    let result = await load(loader, at: 0)
    guard case .success(let loaded) = result else {
      Issue.record("Expected success, got \(result)")
      return
    }
    #expect(loaded === img)
    #expect(loader.image(at: 0) === img)
  }

  @Test("Async failure transitions to failed and is not auto-retried")
  func asyncFailureIsCached() async {
    struct LoadError: Error {}
    let attempts = Attempts()
    let loader = ImageLoader(imageSources: [
      .async({
        await attempts.increment()
        throw LoadError()
      }, placeholder: nil)
    ])

    let first = await load(loader, at: 0)
    guard case .failure = first else {
      Issue.record("Expected first load to fail, got \(first)")
      return
    }

    // A second load returns the cached failure without re-fetching.
    let second = await load(loader, at: 0)
    guard case .failure = second else {
      Issue.record("Expected cached failure, got \(second)")
      return
    }
    #expect(await attempts.count == 1)
  }

  // MARK: - clearFailure

  @Test("clearFailure reports whether a failure existed and allows re-fetch")
  func clearFailureAllowsRefetch() async {
    struct LoadError: Error {}
    let attempts = Attempts()
    let img = makeImage()
    let loader = ImageLoader(imageSources: [
      .async({
        let n = await attempts.increment()
        if n == 1 { throw LoadError() }
        return img
      }, placeholder: nil)
    ])

    _ = await load(loader, at: 0)            // first attempt fails
    #expect(loader.clearFailure(at: 0) == true)
    #expect(loader.clearFailure(at: 0) == false) // nothing left to clear

    let retry = await load(loader, at: 0)    // re-fetch now succeeds
    guard case .success(let loaded) = retry else {
      Issue.record("Expected success after clearFailure, got \(retry)")
      return
    }
    #expect(loaded === img)
    #expect(await attempts.count == 2)
  }

  // MARK: - releaseImages

  @Test("releaseImages drops async state outside the range but keeps .image")
  func releaseKeepsSyncDropsAsync() async {
    let syncImg = makeImage()
    let asyncImg = makeImage()
    let loader = ImageLoader(imageSources: [
      .image(syncImg),                                  // index 0, sync
      .async({ asyncImg }, placeholder: nil),           // index 1, async
    ])
    _ = await load(loader, at: 1)
    #expect(loader.image(at: 1) === asyncImg)

    loader.releaseImages(outside: 0...0)
    #expect(loader.image(at: 0) === syncImg) // sync source kept
    #expect(loader.image(at: 1) == nil)      // async source released
  }

  // MARK: - In-flight behavior

  @Test("A second load while one is in flight does not start another fetch")
  func concurrentLoadIsNoOp() async {
    let img = makeImage()
    let gate = Gate()
    let attempts = Attempts()
    let loader = ImageLoader(imageSources: [
      .async({
        await attempts.increment()
        await gate.wait()
        return img
      }, placeholder: nil)
    ])

    // Start the first load (suspends inside the stub on the gate).
    let first = Task { await self.load(loader, at: 0) }
    // Let the first load reach its suspension before the second call.
    while await attempts.count == 0 { await Task.yield() }

    // A second load while the first is in flight must be a no-op.
    loader.load(at: 0) { _ in Issue.record("In-flight load should not complete a second call") }

    await gate.open()
    _ = await first.value
    #expect(await attempts.count == 1)
  }

  @Test("A result arriving after release does not revive the dropped state")
  func staleResultDoesNotRevive() async {
    let img = makeImage()
    let gate = Gate()
    let attempts = Attempts()
    let loader = ImageLoader(imageSources: [
      .async({
        await attempts.increment()
        await gate.wait()
        return img
      }, placeholder: nil)
    ])

    loader.load(at: 0) { _ in }
    while await attempts.count == 0 { await Task.yield() }

    // Release (and cancel) the in-flight load, then let it resolve.
    loader.releaseImages(outside: 1...1)
    await gate.open()
    // Give the cancelled task a chance to run its (guarded) continuation.
    await Task.yield()

    #expect(loader.image(at: 0) == nil)
  }
}

/// A one-shot gate that suspends callers until `open()` is called.
private actor Gate {
  private var continuations: [CheckedContinuation<Void, Never>] = []
  private var isOpen = false

  func wait() async {
    if isOpen { return }
    await withCheckedContinuation { continuations.append($0) }
  }

  func open() {
    isOpen = true
    let pending = continuations
    continuations.removeAll()
    for continuation in pending { continuation.resume() }
  }
}

/// An actor-isolated counter for tracking how many times a stub loader ran.
private actor Attempts {
  private(set) var count = 0

  @discardableResult
  func increment() -> Int {
    count += 1
    return count
  }
}
