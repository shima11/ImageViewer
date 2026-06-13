import UIKit
import SwiftUI

// MARK: - Transition State

enum TransitionState {
  case appearing
  case presented
  case interactive(progress: CGFloat, translation: CGPoint)
  case dismissing
}

// MARK: - Image Viewer Transition Animator

@MainActor
final class ImageViewerTransitionAnimator {

  // MARK: - Properties

  private weak var imageView: UIImageView?
  private weak var containerView: UIView?
  private weak var backgroundView: UIView?

  private let sourceFrame: CGRect?
  private let sourceContentMode: ContentMode
  private let configuration: ImageViewerConfiguration
  private let image: UIImage

  private var finalFrame: CGRect = .zero
  private var currentAnimator: UIViewPropertyAnimator?

  /// Whether to use reduced motion animations
  private var reduceMotion: Bool {
    UIAccessibility.isReduceMotionEnabled
  }

  // MARK: - Init

  init(
    imageView: UIImageView,
    containerView: UIView,
    backgroundView: UIView,
    image: UIImage,
    sourceFrame: CGRect?,
    sourceContentMode: ContentMode,
    configuration: ImageViewerConfiguration
  ) {
    self.imageView = imageView
    self.containerView = containerView
    self.backgroundView = backgroundView
    self.image = image
    self.sourceFrame = sourceFrame
    self.sourceContentMode = sourceContentMode
    self.configuration = configuration
  }

  // MARK: - Frame Calculations

  private func calculateFinalFrame(in bounds: CGRect) -> CGRect {
    ImageViewerGeometry.aspectFitFrame(imageSize: image.size, in: bounds)
  }

  // MARK: - Appear Animation

  func performAppearAnimation(completion: @escaping () -> Void) {
    guard let containerView = containerView,
          let imageView = imageView,
          let backgroundView = backgroundView
    else {
      completion()
      return
    }

    finalFrame = calculateFinalFrame(in: containerView.bounds)

    // Use simple fade for reduced motion
    if reduceMotion {
      imageView.frame = finalFrame
      imageView.alpha = 0
      imageView.contentMode = .scaleAspectFit
      backgroundView.alpha = 0

      UIView.animate(withDuration: 0.2) {
        imageView.alpha = 1
        backgroundView.alpha = 1
      } completion: { _ in
        completion()
      }
      return
    }

    if let sourceFrame = sourceFrame {
      // Start from source frame
      imageView.frame = sourceFrame
      imageView.layer.cornerRadius = configuration.transitionCornerRadius
      imageView.clipsToBounds = true
      backgroundView.alpha = 0

      // Adjust content mode for fill source
      if sourceContentMode == .fill {
        imageView.contentMode = .scaleAspectFill
      }

      let animator = UIViewPropertyAnimator(
        duration: 0.35,
        dampingRatio: 0.85
      ) {
        imageView.frame = self.finalFrame
        imageView.layer.cornerRadius = 0
        imageView.contentMode = .scaleAspectFit
        backgroundView.alpha = 1
      }

      animator.addCompletion { _ in
        completion()
      }

      currentAnimator = animator
      animator.startAnimation()
    } else {
      // No source frame - slide up from bottom with fade in
      let startFrame = CGRect(
        x: finalFrame.origin.x,
        y: containerView.bounds.height,
        width: finalFrame.width,
        height: finalFrame.height
      )
      imageView.frame = startFrame
      imageView.alpha = 0
      backgroundView.alpha = 0

      let animator = UIViewPropertyAnimator(
        duration: 0.35,
        dampingRatio: 0.85
      ) {
        imageView.frame = self.finalFrame
        imageView.alpha = 1
        backgroundView.alpha = 1
      }

      animator.addCompletion { _ in
        completion()
      }

      currentAnimator = animator
      animator.startAnimation()
    }
  }

  // MARK: - Dismiss Animation

  func performDismissAnimation(completion: @escaping () -> Void) {
    guard let imageView = imageView,
          let backgroundView = backgroundView,
          let containerView = containerView
    else {
      completion()
      return
    }

    // Ensure finalFrame is calculated
    if finalFrame == .zero {
      finalFrame = calculateFinalFrame(in: containerView.bounds)
    }

    // Use simple fade for reduced motion
    if reduceMotion {
      UIView.animate(withDuration: 0.2) {
        imageView.alpha = 0
        backgroundView.alpha = 0
      } completion: { _ in
        completion()
      }
      return
    }

    if let sourceFrame = sourceFrame {
      // Animate back to source frame
      let animator = UIViewPropertyAnimator(
        duration: 0.35,
        dampingRatio: 0.85
      ) {
        imageView.frame = sourceFrame
        imageView.layer.cornerRadius = self.configuration.transitionCornerRadius
        if self.sourceContentMode == .fill {
          imageView.contentMode = .scaleAspectFill
        }
        backgroundView.alpha = 0
      }

      animator.addCompletion { _ in
        completion()
      }

      currentAnimator = animator
      animator.startAnimation()
    } else {
      // No source frame - slide down to bottom with fade out
      let dismissFrame = CGRect(
        x: finalFrame.origin.x,
        y: containerView.bounds.height,
        width: finalFrame.width,
        height: finalFrame.height
      )

      let animator = UIViewPropertyAnimator(
        duration: 0.35,
        dampingRatio: 0.85
      ) {
        imageView.frame = dismissFrame
        imageView.alpha = 0
        backgroundView.alpha = 0
      }

      animator.addCompletion { _ in
        completion()
      }

      currentAnimator = animator
      animator.startAnimation()
    }
  }

  // MARK: - Interactive Transition

  func updateInteractiveTransition(progress: CGFloat, translation: CGPoint) {
    guard let imageView = imageView,
          let backgroundView = backgroundView,
          let containerView = containerView
    else { return }

    // Cancel any running animation
    currentAnimator?.stopAnimation(true)
    currentAnimator = nil

    // Update final frame if needed
    if finalFrame == .zero {
      finalFrame = calculateFinalFrame(in: containerView.bounds)
    }

    // Track the finger by translating finalFrame's center while shrinking it,
    // rather than interpolating toward sourceFrame. Source-frame convergence is
    // handled by the release animation, so they are not applied at once.
    imageView.frame = ImageViewerGeometry.interactiveFrame(
      finalFrame: finalFrame,
      translation: translation,
      progress: progress
    )
    imageView.layer.cornerRadius = configuration.transitionCornerRadius * progress

    // Update background opacity
    let backgroundOpacity = 1.0 - progress * 0.8
    backgroundView.alpha = backgroundOpacity
  }

  // MARK: - Cancel Interactive Transition

  func cancelInteractiveTransition(completion: (() -> Void)? = nil) {
    guard let imageView = imageView,
          let backgroundView = backgroundView,
          let containerView = containerView
    else {
      completion?()
      return
    }

    if finalFrame == .zero {
      finalFrame = calculateFinalFrame(in: containerView.bounds)
    }

    // Use simple fade for reduced motion
    if reduceMotion {
      UIView.animate(withDuration: 0.15) {
        imageView.frame = self.finalFrame
        imageView.alpha = 1
        backgroundView.alpha = 1
      } completion: { _ in
        completion?()
      }
      return
    }

    let animator = UIViewPropertyAnimator(
      duration: 0.3,
      dampingRatio: 0.9
    ) {
      imageView.frame = self.finalFrame
      imageView.layer.cornerRadius = 0
      imageView.contentMode = .scaleAspectFit
      backgroundView.alpha = 1
    }

    animator.addCompletion { _ in
      completion?()
    }

    currentAnimator = animator
    animator.startAnimation()
  }

  // MARK: - Complete Interactive Dismiss

  func completeInteractiveDismiss(completion: @escaping () -> Void) {
    performDismissAnimation(completion: completion)
  }

  // MARK: - Rotation

  /// Recomputes the final frame for the new container bounds and, if the
  /// transition image view is visible (mid-transition), snaps it to the new
  /// frame. Any in-flight animation is finished first so its completion fires.
  func handleRotation() {
    // Finish (not abandon) any in-flight animation so its completion fires.
    // stopAnimation(true) would skip addCompletion, leaving the controller's
    // transitionState stuck mid-transition and the viewer unable to dismiss.
    if let animator = currentAnimator, animator.state == .active {
      animator.stopAnimation(false)
      animator.finishAnimation(at: .end)
    }
    currentAnimator = nil

    guard let containerView = containerView, let imageView = imageView else { return }
    finalFrame = calculateFinalFrame(in: containerView.bounds)

    // Only reposition while the transition image view is on screen. When the
    // zoomable content is shown, it lays itself out independently.
    if !imageView.isHidden {
      imageView.frame = finalFrame
    }
  }
}
