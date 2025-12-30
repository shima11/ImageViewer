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
  private let emptyContentBuilder: (@escaping () -> Void) -> AnyView
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
  private var transitionImageView: UIImageView?
  private var transitionAnimator: ImageViewerTransitionAnimator?

  // MARK: - Loading State

  private var loadedImages: [Int: UIImage] = [:]
  private var loadingTasks: [Int: Task<Void, Never>] = [:]
  private var loadErrors: [Int: Error] = [:]

  // MARK: - Callbacks

  var onDismiss: (() -> Void)?

  // MARK: - Init

  init<
    Overlay: View,
    CloseButton: View,
    PageIndicator: View,
    EmptyContent: View,
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
    @ViewBuilder emptyContent: @escaping (@escaping () -> Void) -> EmptyContent,
    @ViewBuilder loadingContent: @escaping () -> LoadingContent,
    @ViewBuilder errorContent: @escaping (Error) -> ErrorContent
  ) {
    self.imageSources = imageSources
    let validIndex = max(0, min(initialIndex, max(0, imageSources.count - 1)))
    self.initialIndex = validIndex
    self.currentIndex = validIndex
    self.sourceFrames = sourceFrames
    self.sourceContentMode = sourceContentMode
    self.configuration = configuration
    self.overlayBuilder = { context in AnyView(overlay(context)) }
    self.closeButtonBuilder = { dismiss in AnyView(closeButton(dismiss)) }
    self.pageIndicatorBuilder = { current, total in AnyView(pageIndicator(current, total)) }
    self.emptyContentBuilder = { dismiss in AnyView(emptyContent(dismiss)) }
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

    if imageSources.isEmpty {
      setupEmptyState()
    } else {
      loadInitialImage()
    }
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

  private func setupEmptyState() {
    let emptyView = emptyContentBuilder(dismiss)
    let hostingController = UIHostingController(rootView: emptyView)
    addChild(hostingController)
    view.addSubview(hostingController.view)
    hostingController.view.backgroundColor = .clear
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    hostingController.didMove(toParent: self)
    backgroundView.alpha = 1
  }

  // MARK: - Image Loading

  private func loadInitialImage() {
    loadImage(at: currentIndex) { [weak self] result in
      guard let self = self else { return }

      switch result {
      case .success(let image):
        self.setupImageViewer(with: image)
      case .failure(let error):
        self.showError(error)
      }
    }
  }

  private func loadImage(at index: Int, completion: @escaping (Result<UIImage, Error>) -> Void) {
    guard index >= 0, index < imageSources.count else {
      completion(.failure(ImageViewerError.invalidData))
      return
    }

    // Check if already loaded
    if let image = loadedImages[index] {
      completion(.success(image))
      return
    }

    let source = imageSources[index]

    switch source {
    case .image(let image):
      loadedImages[index] = image
      completion(.success(image))

    case .async(let loader, let placeholder):
      // Show placeholder if available
      if let placeholder = placeholder {
        loadedImages[index] = placeholder
      }

      // Show loading indicator
      showLoading()

      // Start async loading
      let task = Task { @MainActor in
        do {
          let image = try await loader()
          self.loadedImages[index] = image
          self.hideLoading()
          completion(.success(image))
        } catch {
          self.loadErrors[index] = error
          self.hideLoading()
          completion(.failure(error))
        }
      }
      loadingTasks[index] = task
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

    setupOverlay()
  }

  private func setupSingleImageViewer(with image: UIImage) {
    // Create transition image view for animation
    let transitionImageView = UIImageView(image: image)
    transitionImageView.contentMode = .scaleAspectFit
    transitionImageView.clipsToBounds = true
    view.addSubview(transitionImageView)
    self.transitionImageView = transitionImageView

    // Create transition animator
    let sourceFrame = sourceFrames?.first
    transitionAnimator = ImageViewerTransitionAnimator(
      imageView: transitionImageView,
      containerView: view,
      backgroundView: backgroundView,
      image: image,
      sourceFrame: sourceFrame,
      sourceContentMode: sourceContentMode,
      configuration: configuration
    )

    // Create zoomable controller (will be shown after transition)
    let controller = ZoomableImageViewController(image: image, configuration: configuration)
    controller.delegate = self
    singleImageController = controller
  }

  private func setupMultipleImagesViewer(initialImage: UIImage) {
    // Create transition image view for animation
    let transitionImageView = UIImageView(image: initialImage)
    transitionImageView.contentMode = .scaleAspectFit
    transitionImageView.clipsToBounds = true
    view.addSubview(transitionImageView)
    self.transitionImageView = transitionImageView

    // Create transition animator
    let sourceFrame = sourceFrames.flatMap { $0.indices.contains(currentIndex) ? $0[currentIndex] : nil }
    transitionAnimator = ImageViewerTransitionAnimator(
      imageView: transitionImageView,
      containerView: view,
      backgroundView: backgroundView,
      image: initialImage,
      sourceFrame: sourceFrame,
      sourceContentMode: sourceContentMode,
      configuration: configuration
    )

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

  private func preloadAdjacentImages() {
    let indicesToPreload = [currentIndex - 1, currentIndex + 1].filter {
      $0 >= 0 && $0 < imageSources.count
    }

    for index in indicesToPreload {
      loadImage(at: index) { _ in }
    }
  }

  private func setupOverlay() {
    updateOverlay()
  }

  private func updateOverlay() {
    // Remove existing overlay
    overlayHostingController?.willMove(toParent: nil)
    overlayHostingController?.view.removeFromSuperview()
    overlayHostingController?.removeFromParent()
    overlayContainerView?.removeFromSuperview()

    // Create overlay content
    let context = ImageViewerContext(
      currentIndex: currentIndex,
      totalCount: imageSources.count,
      dismiss: { [weak self] in self?.dismiss() }
    )

    let overlayContent = OverlayContainerView(
      context: context,
      showPageIndicator: imageSources.count > 1,
      overlay: overlayBuilder,
      closeButton: closeButtonBuilder,
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

      // Configure gesture relationships with UIPageViewController's internal scroll view
      configurePageViewControllerGestures(pageVC)
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

  private func prepareForDismissAnimation() {
    // Hide content controllers
    singleImageController?.view.isHidden = true
    pageViewController?.view.isHidden = true

    // Update transition image view with current image
    if let currentImage = getCurrentImage() {
      transitionImageView?.image = currentImage
      transitionImageView?.isHidden = false

      // Update source frame for current index
      if let sourceFrame = sourceFrames.flatMap({ $0.indices.contains(currentIndex) ? $0[currentIndex] : nil }) {
        transitionAnimator = ImageViewerTransitionAnimator(
          imageView: transitionImageView!,
          containerView: view,
          backgroundView: backgroundView,
          image: currentImage,
          sourceFrame: sourceFrame,
          sourceContentMode: sourceContentMode,
          configuration: configuration
        )
      }
    }

    // Hide overlay
    overlayHostingController?.view.alpha = 0
  }

  private func getCurrentImage() -> UIImage? {
    if singleImageController != nil {
      return loadedImages[0]
    } else {
      return loadedImages[currentIndex]
    }
  }

  // MARK: - Background Tap

  @objc private func handleBackgroundTap() {
    dismiss()
  }

  // MARK: - Page Controller Factory

  private func makePageController(for index: Int) -> ZoomableImageViewController? {
    guard index >= 0, index < imageSources.count else { return nil }

    // Check if image is loaded
    guard let image = loadedImages[index] else {
      // Load image asynchronously
      loadImage(at: index) { [weak self] result in
        // Reload page when image is loaded
        if case .success = result {
          self?.reloadCurrentPage()
        }
      }

      // Return placeholder controller if available
      if let placeholder = imageSources[index].placeholder {
        let controller = ZoomableImageViewController(image: placeholder, configuration: configuration)
        controller.pageIndex = index
        controller.delegate = self
        return controller
      }
      return nil
    }

    let controller = ZoomableImageViewController(image: image, configuration: configuration)
    controller.pageIndex = index
    controller.delegate = self
    return controller
  }

  private func reloadCurrentPage() {
    guard let pageVC = pageViewController,
          let currentController = makePageController(for: currentIndex)
    else { return }

    pageVC.setViewControllers([currentController], direction: .forward, animated: false)
  }

  // MARK: - Page View Controller Gestures

  private func configurePageViewControllerGestures(_ pageVC: UIPageViewController) {
    // Find the internal scroll view of UIPageViewController
    guard let scrollView = pageVC.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else {
      return
    }

    // Store reference for later use
    pageViewControllerScrollView = scrollView
  }

  private weak var pageViewControllerScrollView: UIScrollView?

  private lazy var multiImageDismissPanGesture: UIPanGestureRecognizer = {
    let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleMultiImageDismissPan(_:)))
    gesture.delegate = self
    return gesture
  }()

  @objc private func handleMultiImageDismissPan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: view)
    let velocity = gesture.velocity(in: view)

    switch gesture.state {
    case .changed:
      let progress = min(abs(translation.y) / 300, 1.0)

      // Update transition
      if transitionImageView?.isHidden == true {
        if let currentImage = getCurrentImage() {
          transitionImageView?.image = currentImage

          let sourceFrame = sourceFrames.flatMap { $0.indices.contains(currentIndex) ? $0[currentIndex] : nil }
          transitionAnimator = ImageViewerTransitionAnimator(
            imageView: transitionImageView!,
            containerView: view,
            backgroundView: backgroundView,
            image: currentImage,
            sourceFrame: sourceFrame,
            sourceContentMode: sourceContentMode,
            configuration: configuration
          )
        }

        transitionImageView?.isHidden = false
        pageViewController?.view.isHidden = true
      }

      transitionState = .interactive(progress: progress, translation: translation)
      transitionAnimator?.updateInteractiveTransition(progress: progress, translation: translation)
      overlayHostingController?.view.alpha = 1 - progress

    case .ended, .cancelled:
      let shouldDismiss = abs(translation.y) > configuration.dismissThreshold
        || abs(velocity.y) > configuration.dismissVelocityThreshold

      if shouldDismiss {
        transitionState = .dismissing
        overlayHostingController?.view.alpha = 0
        transitionAnimator?.completeInteractiveDismiss { [weak self] in
          self?.configuration.onDismiss?()
          self?.onDismiss?()
        }
      } else {
        transitionAnimator?.cancelInteractiveTransition { [weak self] in
          self?.transitionState = .presented
          self?.transitionImageView?.isHidden = true
          self?.pageViewController?.view.isHidden = false
          self?.overlayHostingController?.view.alpha = 1
        }
      }

    default:
      break
    }
  }

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
    }
  }
}

// MARK: - UIGestureRecognizerDelegate

extension ImageViewerController: UIGestureRecognizerDelegate {

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard gestureRecognizer == multiImageDismissPanGesture else { return true }

    // Check if current page is at minimum zoom
    if let currentVC = pageViewController?.viewControllers?.first as? ZoomableImageViewController,
       !currentVC.isAtMinimumZoom {
      return false
    }

    // Only allow vertical pan
    let velocity = multiImageDismissPanGesture.velocity(in: view)
    return abs(velocity.y) > abs(velocity.x)
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    // Allow our dismiss gesture to work simultaneously with page view controller's scroll
    if gestureRecognizer == multiImageDismissPanGesture,
       otherGestureRecognizer.view == pageViewControllerScrollView {
      return true
    }
    return false
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

    // Show transition image view for interactive dismiss
    if transitionImageView?.isHidden == true {
      // Update transition image view with current image
      if let currentImage = getCurrentImage() {
        transitionImageView?.image = currentImage

        // Recreate animator with current image and source frame
        let sourceFrame = sourceFrames.flatMap { $0.indices.contains(currentIndex) ? $0[currentIndex] : nil }
        transitionAnimator = ImageViewerTransitionAnimator(
          imageView: transitionImageView!,
          containerView: view,
          backgroundView: backgroundView,
          image: currentImage,
          sourceFrame: sourceFrame,
          sourceContentMode: sourceContentMode,
          configuration: configuration
        )
      }

      transitionImageView?.isHidden = false
      singleImageController?.view.isHidden = true
      pageViewController?.view.isHidden = true
    }

    transitionAnimator?.updateInteractiveTransition(progress: progress, translation: translation)

    // Fade overlay
    overlayHostingController?.view.alpha = 1 - progress
  }

  func zoomableImageViewControllerDidRequestDismiss(_ controller: ZoomableImageViewController) {
    transitionState = .dismissing
    overlayHostingController?.view.alpha = 0

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
      self?.overlayHostingController?.view.alpha = 1
    }
  }
}


// MARK: - Passthrough Container View

private final class PassthroughContainerView: UIView {
  weak var hostedView: UIView?

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // Get the hit view from the hosted SwiftUI view
    guard let hostedView = hostedView else { return nil }

    let hitView = hostedView.hitTest(convert(point, to: hostedView), with: event)

    // If the hit view is the hosting view itself or a generic container,
    // pass the touch through to views behind
    if hitView == nil || hitView == hostedView || isPassthroughView(hitView) {
      return nil
    }

    return hitView
  }

  private func isPassthroughView(_ view: UIView?) -> Bool {
    guard let view = view else { return true }

    let className = String(describing: type(of: view))

    // Pass through for SwiftUI internal container views
    if className.hasPrefix("_") || className.contains("HostingView") {
      // But not if it has gesture recognizers (interactive)
      if let gestures = view.gestureRecognizers, !gestures.isEmpty {
        return false
      }
      return true
    }

    // Pass through for plain UIView containers
    if type(of: view) == UIView.self {
      return true
    }

    return false
  }
}

// MARK: - Overlay Container View

private struct OverlayContainerView: View {
  let context: ImageViewerContext
  let showPageIndicator: Bool
  let overlay: (ImageViewerContext) -> AnyView
  let closeButton: (@escaping () -> Void) -> AnyView
  let pageIndicator: (Int, Int) -> AnyView

  var body: some View {
    Color.clear
      .allowsHitTesting(false)
      .overlay(alignment: .topLeading) {
        // Close button (positioned at top-left, interactive)
        closeButton(context.dismiss)
          .padding(8)
          .padding(.top, safeAreaTop)
      }
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

  private var safeAreaTop: CGFloat {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?
      .windows
      .first?
      .safeAreaInsets.top ?? 0
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
