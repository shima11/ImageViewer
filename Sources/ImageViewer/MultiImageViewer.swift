import SwiftUI
import UIKit

// MARK: - Transition State Holder

/// Observable object to share transition state between UIKit controller and SwiftUI views.
final class TransitionStateHolder: ObservableObject {
  @Published var state: ImageTransitionState = .appearing
  @Published var dragOffset: CGSize = .zero
  @Published var dismissProgress: CGFloat = 0
  @Published var currentIndex: Int = 0
}

// MARK: - Multi Image Viewer

/// A UIKit-based multi-image viewer that supports horizontal page swiping and vertical dismiss gesture.
struct MultiImageViewer<LoadingContent: View, ErrorContent: View>: UIViewControllerRepresentable {
  let imageSources: [ImageSource]
  let sourceFrames: [CGRect]?
  let sourceContentMode: ContentMode
  let configuration: ImageViewerConfiguration

  @Binding var currentIndex: Int
  @Binding var transitionState: ImageTransitionState
  @Binding var hasAppeared: Bool
  @Binding var dragOffset: CGSize
  @Binding var dismissProgress: CGFloat

  @ViewBuilder var loadingContent: () -> LoadingContent
  @ViewBuilder var errorContent: (Error) -> ErrorContent
  let onDismiss: () -> Void

  func makeUIViewController(context: Context) -> MultiImageViewerController {
    let controller = MultiImageViewerController(
      imageSources: imageSources,
      sourceFrames: sourceFrames,
      sourceContentMode: sourceContentMode,
      configuration: configuration,
      initialIndex: currentIndex,
      loadingContent: { AnyView(loadingContent()) },
      errorContent: { AnyView(errorContent($0)) }
    )
    controller.delegate = context.coordinator
    return controller
  }

  func updateUIViewController(_ controller: MultiImageViewerController, context: Context) {
    // Update transition state if changed externally
    controller.updateTransitionState(transitionState)

    // Update current index if changed externally
    if controller.currentIndex != currentIndex {
      controller.setCurrentIndex(currentIndex, animated: false)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, MultiImageViewerControllerDelegate {
    var parent: MultiImageViewer

    init(_ parent: MultiImageViewer) {
      self.parent = parent
    }

    func multiImageViewerController(
      _ controller: MultiImageViewerController,
      didChangePageTo index: Int
    ) {
      parent.currentIndex = index
    }

    func multiImageViewerController(
      _ controller: MultiImageViewerController,
      didUpdateDragOffset offset: CGSize,
      dismissProgress: CGFloat
    ) {
      parent.dragOffset = offset
      parent.dismissProgress = dismissProgress
      if parent.transitionState != .interactive {
        parent.transitionState = .interactive
      }
    }

    func multiImageViewerControllerDidRequestDismiss(_ controller: MultiImageViewerController) {
      parent.transitionState = .dismissing
      parent.dragOffset = .zero
      parent.onDismiss()
    }

    func multiImageViewerControllerDidCancelDismiss(_ controller: MultiImageViewerController) {
      parent.transitionState = .presented
      parent.dragOffset = .zero
      parent.dismissProgress = 0
    }

    func multiImageViewerControllerDidAppear(_ controller: MultiImageViewerController) {
      parent.transitionState = .presented
      parent.hasAppeared = true
    }
  }
}

// MARK: - Delegate Protocol

protocol MultiImageViewerControllerDelegate: AnyObject {
  func multiImageViewerController(_ controller: MultiImageViewerController, didChangePageTo index: Int)
  func multiImageViewerController(
    _ controller: MultiImageViewerController,
    didUpdateDragOffset offset: CGSize,
    dismissProgress: CGFloat
  )
  func multiImageViewerControllerDidRequestDismiss(_ controller: MultiImageViewerController)
  func multiImageViewerControllerDidCancelDismiss(_ controller: MultiImageViewerController)
  func multiImageViewerControllerDidAppear(_ controller: MultiImageViewerController)
}

// MARK: - Multi Image Viewer Controller

final class MultiImageViewerController: UIViewController {
  // MARK: - Properties

  private let imageSources: [ImageSource]
  private let sourceFrames: [CGRect]?
  private let sourceContentMode: ContentMode
  private let configuration: ImageViewerConfiguration
  private let loadingContent: () -> AnyView
  private let errorContent: (Error) -> AnyView

  private(set) var currentIndex: Int
  private var transitionState: ImageTransitionState = .appearing

  /// Shared state holder for transition animations
  let transitionStateHolder = TransitionStateHolder()

  weak var delegate: MultiImageViewerControllerDelegate?

  private var pageViewController: UIPageViewController!
  private var panGestureRecognizer: UIPanGestureRecognizer!

  // MARK: - Init

  init(
    imageSources: [ImageSource],
    sourceFrames: [CGRect]?,
    sourceContentMode: ContentMode,
    configuration: ImageViewerConfiguration,
    initialIndex: Int,
    loadingContent: @escaping () -> AnyView,
    errorContent: @escaping (Error) -> AnyView
  ) {
    self.imageSources = imageSources
    self.sourceFrames = sourceFrames
    self.sourceContentMode = sourceContentMode
    self.configuration = configuration
    self.currentIndex = initialIndex
    self.loadingContent = loadingContent
    self.errorContent = errorContent
    super.init(nibName: nil, bundle: nil)

    // Initialize holder's currentIndex
    transitionStateHolder.currentIndex = initialIndex
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    setupPageViewController()
    setupPanGesture()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Trigger appear animation after a short delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
      self?.delegate?.multiImageViewerControllerDidAppear(self!)
    }
  }

  // MARK: - Setup

  private func setupPageViewController() {
    pageViewController = UIPageViewController(
      transitionStyle: .scroll,
      navigationOrientation: .horizontal,
      options: [.interPageSpacing: 20]
    )
    pageViewController.dataSource = self
    pageViewController.delegate = self

    addChild(pageViewController)
    view.addSubview(pageViewController.view)
    pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
      pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    pageViewController.didMove(toParent: self)

    // Set initial page
    if let initialVC = makePageController(for: currentIndex) {
      pageViewController.setViewControllers([initialVC], direction: .forward, animated: false)
    }
  }

  private func setupPanGesture() {
    panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
    panGestureRecognizer.delegate = self
    view.addGestureRecognizer(panGestureRecognizer)
  }

  // MARK: - Page Management

  private func makePageController(for index: Int) -> ImagePageHostingController? {
    guard index >= 0, index < imageSources.count else { return nil }

    let sourceFrame = sourceFrames.flatMap { $0.indices.contains(index) ? $0[index] : nil }

    let pageView = ImagePageContentView(
      pageIndex: index,
      imageSource: imageSources[index],
      sourceFrame: sourceFrame,
      sourceContentMode: sourceContentMode,
      configuration: configuration,
      transitionState: transitionState,
      transitionStateHolder: transitionStateHolder,
      loadingContent: loadingContent,
      errorContent: errorContent
    )

    let controller = ImagePageHostingController(rootView: AnyView(pageView))
    controller.pageIndex = index
    controller.view.backgroundColor = .clear
    return controller
  }

  func setCurrentIndex(_ index: Int, animated: Bool) {
    guard index != currentIndex, index >= 0, index < imageSources.count else { return }

    let direction: UIPageViewController.NavigationDirection = index > currentIndex ? .forward : .reverse
    currentIndex = index

    if let controller = makePageController(for: index) {
      pageViewController.setViewControllers([controller], direction: direction, animated: animated)
    }
  }

  func updateTransitionState(_ state: ImageTransitionState) {
    transitionState = state
    transitionStateHolder.state = state
  }

  // MARK: - Pan Gesture

  @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: view)
    let velocity = gesture.velocity(in: view)

    switch gesture.state {
    case .changed:
      let offset = CGSize(width: translation.x, height: translation.y)
      let progress = min(abs(translation.y) / 300, 1.0)

      // Update shared state holder for SwiftUI views
      transitionStateHolder.state = .interactive
      transitionStateHolder.dragOffset = offset
      transitionStateHolder.dismissProgress = progress

      delegate?.multiImageViewerController(self, didUpdateDragOffset: offset, dismissProgress: progress)

    case .ended, .cancelled:
      let shouldDismiss = abs(translation.y) > configuration.dismissThreshold
        || abs(velocity.y) > configuration.dismissVelocityThreshold

      if shouldDismiss {
        transitionStateHolder.state = .dismissing
        delegate?.multiImageViewerControllerDidRequestDismiss(self)
      } else {
        // Reset holder state when dismiss is cancelled
        transitionStateHolder.state = .presented
        transitionStateHolder.dragOffset = .zero
        transitionStateHolder.dismissProgress = 0
        delegate?.multiImageViewerControllerDidCancelDismiss(self)
      }

    default:
      break
    }
  }
}

// MARK: - UIPageViewControllerDataSource

extension MultiImageViewerController: UIPageViewControllerDataSource {
  func pageViewController(
    _ pageViewController: UIPageViewController,
    viewControllerBefore viewController: UIViewController
  ) -> UIViewController? {
    guard let hostingController = viewController as? ImagePageHostingController else { return nil }
    return makePageController(for: hostingController.pageIndex - 1)
  }

  func pageViewController(
    _ pageViewController: UIPageViewController,
    viewControllerAfter viewController: UIViewController
  ) -> UIViewController? {
    guard let hostingController = viewController as? ImagePageHostingController else { return nil }
    return makePageController(for: hostingController.pageIndex + 1)
  }
}

// MARK: - UIPageViewControllerDelegate

extension MultiImageViewerController: UIPageViewControllerDelegate {
  func pageViewController(
    _ pageViewController: UIPageViewController,
    didFinishAnimating finished: Bool,
    previousViewControllers: [UIViewController],
    transitionCompleted completed: Bool
  ) {
    guard completed,
          let hostingController = pageViewController.viewControllers?.first as? ImagePageHostingController
    else { return }

    currentIndex = hostingController.pageIndex
    transitionStateHolder.currentIndex = currentIndex
    delegate?.multiImageViewerController(self, didChangePageTo: currentIndex)
  }
}

// MARK: - UIGestureRecognizerDelegate

extension MultiImageViewerController: UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }

    let velocity = pan.velocity(in: view)
    // Only recognize vertical pan gestures
    return abs(velocity.y) > abs(velocity.x)
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    return false
  }
}

// MARK: - Image Page Hosting Controller

final class ImagePageHostingController: UIHostingController<AnyView> {
  var pageIndex: Int = 0

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
  }
}

// MARK: - Image Page Content View

/// SwiftUI view for each page in the multi-image viewer.
private struct ImagePageContentView: View {
  let pageIndex: Int
  let imageSource: ImageSource
  let sourceFrame: CGRect?
  let sourceContentMode: ContentMode
  let configuration: ImageViewerConfiguration
  let initialTransitionState: ImageTransitionState
  let loadingContent: () -> AnyView
  let errorContent: (Error) -> AnyView

  /// Shared state holder for observing transition changes from UIKit
  @ObservedObject var transitionStateHolder: TransitionStateHolder

  @State private var loadedImage: UIImage?
  @State private var isLoading = false
  @State private var loadError: Error?

  // Local state for ZoomableImageView
  // Initialized from initialTransitionState for appear animation
  @State private var localTransitionState: ImageTransitionState
  @State private var localHasAppeared: Bool

  /// Dynamically computed based on transitionStateHolder.currentIndex
  private var isCurrentPage: Bool {
    transitionStateHolder.currentIndex == pageIndex
  }

  init(
    pageIndex: Int,
    imageSource: ImageSource,
    sourceFrame: CGRect?,
    sourceContentMode: ContentMode,
    configuration: ImageViewerConfiguration,
    transitionState: ImageTransitionState,
    transitionStateHolder: TransitionStateHolder,
    loadingContent: @escaping () -> AnyView,
    errorContent: @escaping (Error) -> AnyView
  ) {
    self.pageIndex = pageIndex
    self.imageSource = imageSource
    self.sourceFrame = sourceFrame
    self.sourceContentMode = sourceContentMode
    self.configuration = configuration
    self.initialTransitionState = transitionState
    self.transitionStateHolder = transitionStateHolder
    self.loadingContent = loadingContent
    self.errorContent = errorContent

    // Initialize local state from passed transitionState
    // This enables the appear animation
    self._localTransitionState = State(initialValue: transitionState)
    self._localHasAppeared = State(initialValue: transitionState != .appearing)
  }

  private var displayImage: UIImage? {
    switch imageSource {
    case .image(let image):
      return image
    case .url, .async:
      return loadedImage ?? imageSource.placeholder
    }
  }

  var body: some View {
    Group {
      if let image = displayImage {
        ZoomableImageView(
          image: image,
          sourceFrame: isCurrentPage ? sourceFrame : nil,  // Transition only for current page
          sourceContentMode: sourceContentMode,
          configuration: configuration,
          isCurrentPage: isCurrentPage,
          allowsDismissGesture: false,  // Dismiss is handled by UIKit pan gesture
          transitionState: $localTransitionState,
          hasAppeared: $localHasAppeared,
          onDismiss: {}
        )
        .offset(isCurrentPage ? transitionStateHolder.dragOffset : .zero)
        .allowsHitTesting(isCurrentPage)
      } else if isLoading {
        loadingContent()
      } else if let error = loadError {
        errorContent(error)
      }
    }
    .onChange(of: transitionStateHolder.state) { _, newState in
      // Sync transition state from UIKit controller
      // Only update for dismiss-related states (appear is handled by ZoomableImageView itself)
      guard isCurrentPage else { return }

      if newState == .dismissing {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
          localTransitionState = newState
        }
      } else if newState == .presented && localTransitionState == .interactive {
        // Dismiss was cancelled
        withAnimation(.spring(duration: 0.3)) {
          localTransitionState = newState
        }
      }
    }
    .task {
      await loadImageIfNeeded()
    }
  }

  private func loadImageIfNeeded() async {
    switch imageSource {
    case .image:
      break

    case .url(let url, _):
      await loadImage(from: url)

    case .async(let loader, _):
      await loadImage(using: loader)
    }
  }

  private func loadImage(from url: URL) async {
    isLoading = true
    defer { isLoading = false }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      if let image = UIImage(data: data) {
        loadedImage = image
      } else {
        loadError = ImageLoadingError.invalidData
      }
    } catch {
      loadError = error
    }
  }

  private func loadImage(using loader: @Sendable () async throws -> UIImage) async {
    isLoading = true
    defer { isLoading = false }

    do {
      loadedImage = try await loader()
    } catch {
      loadError = error
    }
  }
}
