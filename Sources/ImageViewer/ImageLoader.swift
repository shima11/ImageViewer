import UIKit

// MARK: - Image Loader

/// Owns the per-index image loading state machine (loading / loaded / failed)
/// and the async loading lifecycle, so `ImageViewerController` can focus on UI.
///
/// The dependency is one-directional: the controller calls into the loader and
/// reacts via completion handlers. The loader knows nothing about view
/// controllers or the UI.
@MainActor
final class ImageLoader {

  /// Per-index image loading state. One state per index makes contradictory
  /// combinations (e.g. loading and loaded at once) unrepresentable.
  private enum ImageState {
    case loading(Task<Void, Never>)
    case loaded(UIImage)
    case failed(Error)

    var image: UIImage? {
      if case .loaded(let image) = self { return image }
      return nil
    }

    var task: Task<Void, Never>? {
      if case .loading(let task) = self { return task }
      return nil
    }

    var error: Error? {
      if case .failed(let error) = self { return error }
      return nil
    }

    var isLoading: Bool {
      if case .loading = self { return true }
      return false
    }
  }

  private let imageSources: [ImageSource]
  private var imageStates: [Int: ImageState] = [:]

  init(imageSources: [ImageSource]) {
    self.imageSources = imageSources
    preloadSyncImages()
  }

  deinit {
    for state in imageStates.values {
      state.task?.cancel()
    }
  }

  /// Pre-loads all synchronous (`.image`) sources.
  private func preloadSyncImages() {
    for (index, source) in imageSources.enumerated() {
      if let image = source.syncImage {
        imageStates[index] = .loaded(image)
      }
    }
  }

  /// The already-loaded image for `index`, or `nil` if not loaded yet.
  func image(at index: Int) -> UIImage? {
    imageStates[index]?.image
  }

  /// Loads the image at `index`, calling `completion` with the result.
  ///
  /// No-ops if a load is already in flight. Failed indices are not retried
  /// automatically (call `clearFailure(at:)` first).
  func load(at index: Int, completion: @escaping (Result<UIImage, Error>) -> Void) {
    guard index >= 0, index < imageSources.count else {
      completion(.failure(ImageViewerError.indexOutOfRange(index: index, count: imageSources.count)))
      return
    }

    if let image = imageStates[index]?.image {
      completion(.success(image))
      return
    }

    if imageStates[index]?.isLoading == true {
      return
    }

    if let error = imageStates[index]?.error {
      completion(.failure(error))
      return
    }

    let source = imageSources[index]

    guard case .async(let loader, _) = source else {
      completion(.failure(ImageViewerError.invalidData))
      return
    }

    let task = Task { @MainActor [weak self] in
      do {
        let image = try await loader()
        guard let self else { return }
        self.imageStates[index] = .loaded(image)
        completion(.success(image))
      } catch {
        guard let self else { return }
        ImageViewerLog.loading.error(
          "Failed to load image at index \(index, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
        self.imageStates[index] = .failed(error)
        completion(.failure(error))
      }
    }
    imageStates[index] = .loading(task)
  }

  /// Clears a cached failure so the index can be re-fetched.
  /// - Returns: `true` if there was a failure to clear.
  @discardableResult
  func clearFailure(at index: Int) -> Bool {
    guard imageStates[index]?.error != nil else { return false }
    imageStates.removeValue(forKey: index)
    return true
  }

  /// Releases async-loaded state outside `keepRange` to bound memory. This drops
  /// both cached images and cached failures, so a released index can be
  /// re-fetched when revisited. Pre-loaded `.image` sources are kept.
  func releaseImages(outside keepRange: ClosedRange<Int>) {
    for index in imageSources.indices where !keepRange.contains(index) {
      guard case .async = imageSources[index] else { continue }
      imageStates.removeValue(forKey: index)
    }
  }

}
