import SwiftUI
import UIKit

// MARK: - Image Viewer Controller

final class ImageViewerController: UIViewController {

  // MARK: - Properties

  private let imageSources: [ImageSource]
  private let initialIndex: Int
  private let sourceFrames: [CGRect]?
  private let sourceContentMode: ContentMode
  private let configuration: ImageViewerConfiguration

  private let overlayBuilder: (ImageViewerContext) -> AnyView
  private let closeButtonBuilder: (@escaping () -> Void) -> AnyView
  private let pageIndicatorBuilder: (Int, Int) -> AnyView
  private let loadingContentBuilder: () -> AnyView
  private let errorContentBuilder: (Error) -> AnyView

  private var currentIndex: Int
  private var transitionState: TransitionState = .appearing

  // MARK: - UI Components

  private var backgroundView: UIView!
  private var pageViewController: UIPageViewController?
  private var singleImageController: ZoomableImageViewController?
  private var overlayHostingController: UIHostingController<AnyView>?
  private var overlayContainerView: PassthroughContainerView?
  private var closeButtonHostingController: UIHostingController<AnyView>?
  private var transitionImageView: UIImageView?
  private var transitionAnimator: ImageViewerTransitionAnimator?
  private var isOverlayVisible: Bool = true

  // MARK: - Loading State

  private var loadedImages: [Int: UIImage] = [:]
  private var loadingTasks: [Int: Task<Void, Never>] = [:]
  private var loadErrors: [Int: Error] = [:]
  private var cachedPageControllers: [Int: ZoomableImageViewController] = [:]

  // MARK: - Callbacks

  var onDismiss: (() -> Void)?

  // MARK: - Init

  init<
    Overlay: View,
    CloseButton: View,
    PageIndicator: View,
    LoadingContent: View,
    ErrorContent: View
  >(
    imageSources: [ImageSource],
    initialIndex: Int,
    sourceFrames: [CGRect]?,
    sourceContentMode: ContentMode,
    configuration: ImageViewerConfiguration,
    @ViewBuilder overlay: @escaping (ImageViewerContext) -> Overlay,
    @ViewBuilder closeButton: @escaping (@escaping () -> Void) -> CloseButton,
    @ViewBuilder pageIndicator: @escaping (Int, Int) -> PageIndicator,
    @ViewBuilder loadingContent: @escaping () -> LoadingContent,
    @ViewBuilder errorContent: @escaping (Error) -> ErrorContent
  ) {
    self.imageSources = imageSources
    let validIndex = ImageViewerIndex.clamp(initialIndex, count: imageSources.count)
    self.initialIndex = validIndex
    self.currentIndex = validIndex
    self.sourceFrames = sourceFrames
    self.sourceContentMode = sourceContentMode
    self.configuration = configuration
    self.overlayBuilder = { context in AnyView(overlay(context)) }
    self.closeButtonBuilder = { dismiss in AnyView(closeButton(dismiss)) }
    self.pageIndicatorBuilder = { current, total in AnyView(pageIndicator(current, total)) }
    self.loadingContentBuilder = { AnyView(loadingContent()) }
    self.errorContentBuilder = { error in AnyView(errorContent(error)) }
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setupBackground()
    loadInitialImage()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if case .appearing = transitionState {
      performAppearAnimation()
    }
  }

  override var prefersStatusBarHidden: Bool {
    return true
  }

  // MARK: - Setup

  private func setupBackground() {
    backgroundView = UIView()
    backgroundView.backgroundColor = UIColor(configuration.backgroundColor)
    backgroundView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(backgroundView)

    NSLayoutConstraint.activate([
      backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
      backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    // Add tap gesture to background
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
    backgroundView.addGestureRecognizer(tapGesture)
  }

  // MARK: - Image Loading

  private func loadInitialImage() {
    // Pre-load all UIImage sources synchronously
    preloadAllSyncImages()

    // Load the initial image
    if let image = loadedImages[currentIndex] {
      setupImageViewer(with: image)
    } else {
      // Need to load async
      showLoading()
      loadImageAsync(at: currentIndex) { [weak self] result in
        guard let self = self else { return }
        self.hideLoading()

        switch result {
        case .success(let image):
          self.setupImageViewer(with: image)
        case .failure(let error):
          self.showError(error)
        }
      }
    }
  }

  private func preloadAllSyncImages() {
    for (index, source) in imageSources.enumerated() {
      if case .image(let image) = source {
        loadedImages[index] = image
      }
    }
  }

  private func loadImageAsync(at index: Int, completion: @escaping (Result<UIImage, Error>) -> Void) {
    guard index >= 0, index < imageSources.count else {
      completion(.failure(ImageViewerError.invalidData))
      return
    }

    // Already loaded
    if let image = loadedImages[index] {
      completion(.success(image))
      return
    }

    // Already loading
    if loadingTasks[index] != nil {
      return
    }

    // Already failed - do not retry automatically to avoid refetch loops
    if let error = loadErrors[index] {
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
        self.loadedImages[index] = image
        self.loadingTasks.removeValue(forKey: index)
        completion(.success(image))

        // Update cached controller if exists
        self.updateCachedController(at: index, with: image)
      } catch {
        guard let self else { return }
        self.loadErrors[index] = error
        self.loadingTasks.removeValue(forKey: index)
        completion(.failure(error))
      }
    }
    loadingTasks[index] = task
  }

  private func updateCachedController(at index: Int, with image: UIImage) {
    guard let controller = cachedPageControllers[index] else { return }
    controller.updateImage(image)

    // If this is the current page, ensure it's displayed
    if index == currentIndex {
      // Force refresh
      if let pageVC = pageViewController {
        pageVC.setViewControllers([controller], direction: .forward, animated: false)
      }
    }
  }

  private func showLoading() {
    // Default: UIActivityIndicatorView
    let indicator = UIActivityIndicatorView(style: .large)
    indicator.color = .white
    indicator.tag = 999
    indicator.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(indicator)

    NSLayoutConstraint.activate([
      indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])

    indicator.startAnimating()
  }

  private func hideLoading() {
    view.viewWithTag(999)?.removeFromSuperview()
  }

  private func showError(_ error: Error) {
    let errorView = errorContentBuilder(error)
    let hostingController = UIHostingController(rootView: errorView)
    addChild(hostingController)
    view.addSubview(hostingController.view)
    hostingController.view.backgroundColor = .clear
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      hostingController.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])

    hostingController.didMove(toParent: self)
    backgroundView.alpha = 1
  }

  // MARK: - Image Viewer Setup

  private func setupImageViewer(with image: UIImage) {
    if imageSources.count == 1 {
      setupSingleImageViewer(with: image)
    } else {
      setupMultipleImagesViewer(initialImage: image)
    }

    updateOverlay()
  }

  private func setupSingleImageViewer(with image: UIImage) {
    setupTransitionViews(with: image, sourceIndex: 0)

    // Create zoomable controller (will be shown after transition)
    let controller = ZoomableImageViewController(image: image, configuration: configuration)
    controller.delegate = self
    singleImageController = controller
  }

  private func setupMultipleImagesViewer(initialImage: UIImage) {
    setupTransitionViews(with: initialImage, sourceIndex: currentIndex)

    // Create page view controller (will be shown after transition)
    let pageVC = UIPageViewController(
      transitionStyle: .scroll,
      navigationOrientation: .horizontal,
      options: [.interPageSpacing: 20]
    )
    pageVC.dataSource = self
    pageVC.delegate = self
    pageViewController = pageVC

    // Preload adjacent images
    preloadAdjacentImages()
  }

  private func setupTransitionViews(with image: UIImage, sourceIndex: Int) {
    // Create transition image view for animation
    let transitionImageView = UIImageView(image: image)
    transitionImageView.contentMode = .scaleAspectFit
    transitionImageView.clipsToBounds = true
    view.addSubview(transitionImageView)
    self.transitionImageView = transitionImageView

    // Create transition animator
    transitionAnimator = ImageViewerTransitionAnimator(
      imageView: transitionImageView,
      containerView: view,
      backgroundView: backgroundView,
      image: image,
      sourceFrame: getSourceFrame(for: sourceIndex),
      sourceContentMode: sourceContentMode,
      configuration: configuration
    )
  }

  private func preloadAdjacentImages() {
    let indicesToPreload = [currentIndex - 1, currentIndex + 1].filter {
      $0 >= 0 && $0 < imageSources.count && loadedImages[$0] == nil
    }

    for index in indicesToPreload {
      loadImageAsync(at: index) { _ in }
    }

    // Clean up cached controllers that are far from current index
    cleanupDistantCachedControllers()
  }

  /// Remove cached controllers that are more than 2 pages away from current index
  private func cleanupDistantCachedControllers() {
    let keepRange = (currentIndex - 2)...(currentIndex + 2)
    let keysToRemove = cachedPageControllers.keys.filter { !keepRange.contains($0) }
    for key in keysToRemove {
      cachedPageControllers.removeValue(forKey: key)
    }
  }

  private func updateOverlay() {
    // Remove existing overlay
    overlayHostingController?.willMove(toParent: nil)
    overlayHostingController?.view.removeFromSuperview()
    overlayHostingController?.removeFromParent()
    overlayContainerView?.removeFromSuperview()
    closeButtonHostingController?.willMove(toParent: nil)
    closeButtonHostingController?.view.removeFromSuperview()
    closeButtonHostingController?.removeFromParent()

    // Create overlay content (without close button)
    let context = ImageViewerContext(
      currentIndex: currentIndex,
      totalCount: imageSources.count,
      dismiss: { [weak self] in self?.dismiss() }
    )

    let overlayContent = OverlayContainerView(
      context: context,
      showPageIndicator: imageSources.count > 1,
      overlay: overlayBuilder,
      pageIndicator: pageIndicatorBuilder
    )

    let hostingController = UIHostingController(rootView: AnyView(overlayContent))
    hostingController.view.backgroundColor = .clear

    addChild(hostingController)

    // Wrap hosting view in passthrough container
    let containerView = PassthroughContainerView()
    containerView.hostedView = hostingController.view
    containerView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(containerView)

    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(hostingController.view)

    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: view.topAnchor),
      containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
    ])

    hostingController.didMove(toParent: self)
    overlayHostingController = hostingController
    overlayContainerView = containerView

    // Add close button separately (outside of PassthroughContainerView)
    let closeButtonView = closeButtonBuilder { [weak self] in self?.dismiss() }
      .padding(8)

    let closeButtonController = UIHostingController(rootView: AnyView(closeButtonView))
    closeButtonController.view.backgroundColor = .clear
    closeButtonController.view.translatesAutoresizingMaskIntoConstraints = false

    addChild(closeButtonController)
    view.addSubview(closeButtonController.view)

    // Pin to the safe area so the position is correct regardless of when the
    // safe area resolves (e.g. before the window is attached) and after rotation.
    NSLayoutConstraint.activate([
      closeButtonController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      closeButtonController.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
    ])

    closeButtonController.didMove(toParent: self)
    closeButtonHostingController = closeButtonController
  }

  // MARK: - Appear Animation

  private func performAppearAnimation() {
    transitionAnimator?.performAppearAnimation { [weak self] in
      self?.transitionState = .presented
      self?.showContentAfterAppear()
    }
  }

  private func showContentAfterAppear() {
    // Hide transition image view
    transitionImageView?.isHidden = true

    if let singleController = singleImageController {
      // Show single image controller
      addChild(singleController)
      view.insertSubview(singleController.view, aboveSubview: backgroundView)
      singleController.view.translatesAutoresizingMaskIntoConstraints = false

      NSLayoutConstraint.activate([
        singleController.view.topAnchor.constraint(equalTo: view.topAnchor),
        singleController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        singleController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        singleController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      ])

      singleController.didMove(toParent: self)
    } else if let pageVC = pageViewController {
      // Show page view controller
      addChild(pageVC)
      view.insertSubview(pageVC.view, aboveSubview: backgroundView)
      pageVC.view.translatesAutoresizingMaskIntoConstraints = false

      NSLayoutConstraint.activate([
        pageVC.view.topAnchor.constraint(equalTo: view.topAnchor),
        pageVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        pageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        pageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      ])

      pageVC.didMove(toParent: self)

      // Set initial page
      if let initialController = makePageController(for: currentIndex) {
        pageVC.setViewControllers([initialController], direction: .forward, animated: false)
      }
    }

    // Bring overlay to front
    if let containerView = overlayContainerView {
      view.bringSubviewToFront(containerView)
    }
  }

  // MARK: - Dismiss

  private func dismiss() {
    guard case .presented = transitionState else { return }

    transitionState = .dismissing

    // Prepare for dismiss animation
    prepareForDismissAnimation()

    transitionAnimator?.performDismissAnimation { [weak self] in
      self?.configuration.onDismiss?()
      self?.onDismiss?()
    }
  }

  private func toggleOverlayVisibility() {
    isOverlayVisible.toggle()

    let alpha: CGFloat = isOverlayVisible ? 1 : 0

    if UIAccessibility.isReduceMotionEnabled {
      // Instant change for reduced motion
      overlayContainerView?.alpha = alpha
      closeButtonHostingController?.view.alpha = alpha
    } else {
      UIView.animate(withDuration: 0.2) {
        self.overlayContainerView?.alpha = alpha
        self.closeButtonHostingController?.view.alpha = alpha
      }
    }
  }

  private func prepareForDismissAnimation() {
    // Hide content controllers
    singleImageController?.view.isHidden = true
    pageViewController?.view.isHidden = true

    // Update transition image view with current image
    if let currentImage = getCurrentImage() {
      transitionImageView?.image = currentImage
      transitionImageView?.isHidden = false

      // Update animator with current image and source frame
      if let imageView = transitionImageView {
        transitionAnimator = ImageViewerTransitionAnimator(
          imageView: imageView,
          containerView: view,
          backgroundView: backgroundView,
          image: currentImage,
          sourceFrame: getSourceFrame(for: currentIndex),
          sourceContentMode: sourceContentMode,
          configuration: configuration
        )
      }
    }

    // Hide overlay
    updateOverlayAlpha(0)
  }

  private func getCurrentImage() -> UIImage? {
    loadedImages[singleImageController != nil ? 0 : currentIndex]
  }

  private func getSourceFrame(for index: Int) -> CGRect? {
    sourceFrames.flatMap { $0.indices.contains(index) ? $0[index] : nil }
  }

  private func updateOverlayAlpha(_ alpha: CGFloat) {
    // Respect isOverlayVisible state - don't show if user has hidden the overlay
    let effectiveAlpha = isOverlayVisible ? alpha : 0
    overlayHostingController?.view.alpha = effectiveAlpha
    closeButtonHostingController?.view.alpha = effectiveAlpha
  }

  private func prepareTransitionForInteractiveDismiss() {
    guard transitionImageView?.isHidden == true,
          let currentImage = getCurrentImage(),
          let imageView = transitionImageView
    else { return }

    imageView.image = currentImage
    transitionAnimator = ImageViewerTransitionAnimator(
      imageView: imageView,
      containerView: view,
      backgroundView: backgroundView,
      image: currentImage,
      sourceFrame: getSourceFrame(for: currentIndex),
      sourceContentMode: sourceContentMode,
      configuration: configuration
    )

    imageView.isHidden = false
    singleImageController?.view.isHidden = true
    pageViewController?.view.isHidden = true
  }

  // MARK: - Background Tap

  @objc private func handleBackgroundTap() {
    dismiss()
  }

  // MARK: - Page Controller Factory

  private func makePageController(for index: Int) -> ZoomableImageViewController? {
    guard index >= 0, index < imageSources.count else { return nil }

    // Return cached controller if available and has correct image
    if let cached = cachedPageControllers[index] {
      // If image is now loaded but controller has placeholder, update it
      if let image = loadedImages[index], cached.currentImage !== image {
        cached.updateImage(image)
      }
      return cached
    }

    // Create new controller
    let image: UIImage
    if let loadedImage = loadedImages[index] {
      image = loadedImage
    } else {
      // Use placeholder or create temporary one
      image = imageSources[index].placeholder ?? Self.transparentPlaceholder

      // Start loading async image
      loadImageAsync(at: index) { _ in }
    }

    let controller = ZoomableImageViewController(image: image, configuration: configuration)
    controller.pageIndex = index
    controller.delegate = self

    // Cache the controller
    cachedPageControllers[index] = controller

    return controller
  }

  /// Shared 1x1 transparent placeholder image
  private static let transparentPlaceholder: UIImage = {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
    return renderer.image { context in
      UIColor.clear.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
  }()

  // MARK: - Cleanup

  deinit {
    loadingTasks.values.forEach { $0.cancel() }
  }
}

// MARK: - UIPageViewControllerDataSource

extension ImageViewerController: UIPageViewControllerDataSource {

  func pageViewController(
    _ pageViewController: UIPageViewController,
    viewControllerBefore viewController: UIViewController
  ) -> UIViewController? {
    guard let zoomableVC = viewController as? ZoomableImageViewController else { return nil }
    return makePageController(for: zoomableVC.pageIndex - 1)
  }

  func pageViewController(
    _ pageViewController: UIPageViewController,
    viewControllerAfter viewController: UIViewController
  ) -> UIViewController? {
    guard let zoomableVC = viewController as? ZoomableImageViewController else { return nil }
    return makePageController(for: zoomableVC.pageIndex + 1)
  }
}

// MARK: - UIPageViewControllerDelegate

extension ImageViewerController: UIPageViewControllerDelegate {

  func pageViewController(
    _ pageViewController: UIPageViewController,
    didFinishAnimating finished: Bool,
    previousViewControllers: [UIViewController],
    transitionCompleted completed: Bool
  ) {
    guard completed,
          let zoomableVC = pageViewController.viewControllers?.first as? ZoomableImageViewController
    else { return }

    let oldIndex = currentIndex
    currentIndex = zoomableVC.pageIndex

    if oldIndex != currentIndex {
      configuration.onPageChange?(currentIndex)
      updateOverlay()

      // Preload adjacent images for smooth scrolling
      preloadAdjacentImages()
    }
  }
}

// MARK: - ZoomableImageViewControllerDelegate

extension ImageViewerController: ZoomableImageViewControllerDelegate {

  func zoomableImageViewController(
    _ controller: ZoomableImageViewController,
    didUpdateDismissProgress progress: CGFloat,
    translation: CGPoint
  ) {
    transitionState = .interactive(progress: progress, translation: translation)
    prepareTransitionForInteractiveDismiss()
    transitionAnimator?.updateInteractiveTransition(progress: progress, translation: translation)
    updateOverlayAlpha(1 - progress)
  }

  func zoomableImageViewControllerDidRequestDismiss(_ controller: ZoomableImageViewController) {
    transitionState = .dismissing
    updateOverlayAlpha(0)
    transitionAnimator?.completeInteractiveDismiss { [weak self] in
      self?.configuration.onDismiss?()
      self?.onDismiss?()
    }
  }

  func zoomableImageViewControllerDidCancelDismiss(_ controller: ZoomableImageViewController) {
    transitionAnimator?.cancelInteractiveTransition { [weak self] in
      self?.transitionState = .presented
      self?.transitionImageView?.isHidden = true
      self?.singleImageController?.view.isHidden = false
      self?.pageViewController?.view.isHidden = false
      self?.updateOverlayAlpha(1)
    }
  }

  func zoomableImageViewControllerDidSingleTap(_ controller: ZoomableImageViewController) {
    toggleOverlayVisibility()
  }
}


// MARK: - Passthrough Container View

private final class PassthroughContainerView: UIView {
  weak var hostedView: UIView?

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // Skip hit testing if container is hidden (alpha near zero)
    if alpha < 0.01 {
      return nil
    }

    // Get the hit view from the hosted SwiftUI view
    guard let hostedView = hostedView else { return nil }

    let hitView = hostedView.hitTest(convert(point, to: hostedView), with: event)

    // If nothing was hit or only the hosting view itself was hit, pass through
    if hitView == nil || hitView == hostedView {
      return nil
    }

    // Check if the hit view contains a SwiftUI Button by examining view hierarchy
    if containsSwiftUIButton(hitView, in: hostedView) {
      return hostedView
    }

    // Pass through for non-interactive views
    return nil
  }

  private func containsSwiftUIButton(_ view: UIView?, in hostingView: UIView) -> Bool {
    guard let view = view else { return false }

    var current: UIView? = view
    while let v = current, v != hostingView {
      let className = String(describing: type(of: v))

      // SwiftUI Button uses internal views with "Button" in the name
      if className.contains("Button") {
        return true
      }

      // Check for gesture recognizers (for custom interactive views)
      if let gestures = v.gestureRecognizers, !gestures.isEmpty {
        return true
      }

      // Check for UIControl subclasses
      if v is UIControl {
        return true
      }

      current = v.superview
    }

    return false
  }
}

// MARK: - Overlay Container View

private struct OverlayContainerView: View {
  let context: ImageViewerContext
  let showPageIndicator: Bool
  let overlay: (ImageViewerContext) -> AnyView
  let pageIndicator: (Int, Int) -> AnyView

  var body: some View {
    Color.clear
      .allowsHitTesting(false)
      .overlay {
        // Custom overlay (pass through touches)
        overlay(context)
          .allowsHitTesting(false)
      }
      .overlay(alignment: .bottom) {
        // Page indicator (positioned at bottom-center)
        if showPageIndicator {
          pageIndicator(context.currentIndex, context.totalCount)
            .padding(.bottom, 50)
            .allowsHitTesting(false)
        }
      }
  }
}

// MARK: - Image Viewer Error

enum ImageViewerError: Error, LocalizedError {
  case invalidData

  var errorDescription: String? {
    switch self {
    case .invalidData:
      return "The image data is invalid or corrupted."
    }
  }
}
