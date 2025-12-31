import UIKit

// MARK: - Delegate Protocol

@MainActor
protocol ZoomableImageViewControllerDelegate: AnyObject {
  func zoomableImageViewController(
    _ controller: ZoomableImageViewController,
    didUpdateDismissProgress progress: CGFloat,
    translation: CGPoint
  )
  func zoomableImageViewControllerDidRequestDismiss(_ controller: ZoomableImageViewController)
  func zoomableImageViewControllerDidCancelDismiss(_ controller: ZoomableImageViewController)
  func zoomableImageViewControllerDidSingleTap(_ controller: ZoomableImageViewController)
}

// MARK: - Zoomable Image View Controller

final class ZoomableImageViewController: UIViewController {

  // MARK: - Properties

  private let scrollView = UIScrollView()
  private let imageView = UIImageView()
  private let image: UIImage
  private let configuration: ImageViewerConfiguration

  weak var delegate: ZoomableImageViewControllerDelegate?

  /// Page index for use in UIPageViewController
  var pageIndex: Int = 0

  /// Whether to enable the built-in dismiss gesture
  /// Set to false when used inside UIPageViewController to avoid gesture conflicts
  var enableDismissGesture: Bool = true

  private var hasInitializedZoomScale = false

  // MARK: - Gesture Recognizers

  private lazy var singleTapGesture: UITapGestureRecognizer = {
    let gesture = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
    gesture.numberOfTapsRequired = 1
    gesture.require(toFail: doubleTapGesture)
    return gesture
  }()

  private lazy var doubleTapGesture: UITapGestureRecognizer = {
    let gesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
    gesture.numberOfTapsRequired = 2
    return gesture
  }()

  private lazy var dismissPanGesture: UIPanGestureRecognizer = {
    let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
    gesture.delegate = self
    return gesture
  }()

  // MARK: - Init

  init(image: UIImage, configuration: ImageViewerConfiguration) {
    self.image = image
    self.configuration = configuration
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setupViews()
    setupGestures()
    setupAccessibility()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    // Only set zoom scale on first layout
    if !hasInitializedZoomScale {
      updateZoomScaleForSize(view.bounds.size)
      hasInitializedZoomScale = true
    } else {
      // Update min/max scales but preserve current zoom
      updateZoomScaleLimits(for: view.bounds.size)
    }
    centerImageInScrollView()
  }

  // MARK: - Setup

  private func setupViews() {
    view.backgroundColor = .clear

    // ScrollView setup
    scrollView.delegate = self
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.decelerationRate = .fast
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scrollView)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    // ImageView setup (using manual frame, not Auto Layout)
    imageView.image = image
    imageView.contentMode = .scaleAspectFit
    scrollView.addSubview(imageView)

    // Set initial image size
    let imageSize = image.size
    imageView.frame = CGRect(origin: .zero, size: imageSize)
    scrollView.contentSize = imageSize
  }

  private func setupGestures() {
    scrollView.addGestureRecognizer(singleTapGesture)
    scrollView.addGestureRecognizer(doubleTapGesture)

    if enableDismissGesture {
      view.addGestureRecognizer(dismissPanGesture)
    }
  }

  private func setupAccessibility() {
    imageView.isAccessibilityElement = true
    imageView.accessibilityLabel = "Image"
    imageView.accessibilityTraits = .image
    imageView.accessibilityHint = "Double tap to zoom, swipe down to dismiss"
  }

  // MARK: - Zoom Scale

  private func updateZoomScaleForSize(_ size: CGSize) {
    guard image.size.width > 0, image.size.height > 0 else { return }

    let widthScale = size.width / image.size.width
    let heightScale = size.height / image.size.height
    let minZoomScale = min(widthScale, heightScale)

    scrollView.minimumZoomScale = minZoomScale
    scrollView.maximumZoomScale = minZoomScale * configuration.maxScale
    scrollView.zoomScale = minZoomScale
  }

  private func updateZoomScaleLimits(for size: CGSize) {
    guard image.size.width > 0, image.size.height > 0 else { return }

    let widthScale = size.width / image.size.width
    let heightScale = size.height / image.size.height
    let minZoomScale = min(widthScale, heightScale)

    scrollView.minimumZoomScale = minZoomScale
    scrollView.maximumZoomScale = minZoomScale * configuration.maxScale
  }

  private func centerImageInScrollView() {
    let scrollViewSize = scrollView.bounds.size
    let imageViewSize = imageView.frame.size

    let horizontalPadding = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
    let verticalPadding = max(0, (scrollViewSize.height - imageViewSize.height) / 2)

    scrollView.contentInset = UIEdgeInsets(
      top: verticalPadding,
      left: horizontalPadding,
      bottom: verticalPadding,
      right: horizontalPadding
    )
  }

  // MARK: - Single Tap

  @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
    delegate?.zoomableImageViewControllerDidSingleTap(self)
  }

  // MARK: - Double Tap

  @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
    let location = gesture.location(in: imageView)

    if scrollView.zoomScale > scrollView.minimumZoomScale {
      // Zoom out
      scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
    } else {
      // Zoom in to double tap scale
      let targetScale = scrollView.minimumZoomScale * configuration.doubleTapScale
      let zoomRect = zoomRectForScale(targetScale, center: location)
      scrollView.zoom(to: zoomRect, animated: true)
    }
  }

  private func zoomRectForScale(_ scale: CGFloat, center: CGPoint) -> CGRect {
    let size = CGSize(
      width: scrollView.bounds.width / scale,
      height: scrollView.bounds.height / scale
    )
    let origin = CGPoint(
      x: center.x - size.width / 2,
      y: center.y - size.height / 2
    )
    return CGRect(origin: origin, size: size)
  }

  // MARK: - Dismiss Pan Gesture

  @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: view)
    let velocity = gesture.velocity(in: view)

    switch gesture.state {
    case .changed:
      let progress = min(abs(translation.y) / 300, 1.0)
      delegate?.zoomableImageViewController(
        self,
        didUpdateDismissProgress: progress,
        translation: translation
      )

    case .ended, .cancelled:
      let shouldDismiss = abs(translation.y) > configuration.dismissThreshold
        || abs(velocity.y) > configuration.dismissVelocityThreshold

      if shouldDismiss {
        delegate?.zoomableImageViewControllerDidRequestDismiss(self)
      } else {
        delegate?.zoomableImageViewControllerDidCancelDismiss(self)
      }

    default:
      break
    }
  }

  // MARK: - Public Methods

  /// Reset zoom to minimum scale
  func resetZoom(animated: Bool = true) {
    if animated {
      UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
        self.scrollView.zoomScale = self.scrollView.minimumZoomScale
      }
    } else {
      scrollView.zoomScale = scrollView.minimumZoomScale
    }
  }

  /// Get the current visible rect of the image for transition
  var currentImageFrame: CGRect {
    let imageViewFrame = imageView.frame
    let scrollViewFrame = scrollView.convert(imageViewFrame, to: view)
    return scrollViewFrame
  }

  /// Whether the image is at minimum zoom scale (not zoomed)
  var isAtMinimumZoom: Bool {
    return scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01
  }
}

// MARK: - UIScrollViewDelegate

extension ZoomableImageViewController: UIScrollViewDelegate {

  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return imageView
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    centerImageInScrollView()
  }
}

// MARK: - UIGestureRecognizerDelegate

extension ZoomableImageViewController: UIGestureRecognizerDelegate {

  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard gestureRecognizer == dismissPanGesture else { return true }

    // Only allow dismiss gesture when not zoomed
    guard isAtMinimumZoom else { return false }

    // Only allow vertical pan (this allows horizontal pans to go to UIPageViewController)
    let velocity = dismissPanGesture.velocity(in: view)
    return abs(velocity.y) > abs(velocity.x)
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    guard gestureRecognizer == dismissPanGesture else { return false }

    // Allow simultaneous recognition with UIPageViewController's scroll view
    if let otherScrollView = otherGestureRecognizer.view as? UIScrollView,
       otherScrollView != scrollView {
      return true
    }

    // Allow simultaneous with our own scrollView when at minimum zoom
    if otherGestureRecognizer == scrollView.panGestureRecognizer {
      return isAtMinimumZoom
    }

    return false
  }
}
