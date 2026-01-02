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
    guard image.size.width > 0, image.size.height > 0 else {
      return bounds
    }

    let imageAspect = image.size.width / image.size.height
    let boundsAspect = bounds.width / bounds.height

    let finalSize: CGSize
    if imageAspect > boundsAspect {
      finalSize = CGSize(width: bounds.width, height: bounds.width / imageAspect)
    } else {
      finalSize = CGSize(width: bounds.height * imageAspect, height: bounds.height)
    }

    return CGRect(
      x: (bounds.width - finalSize.width) / 2,
      y: (bounds.height - finalSize.height) / 2,
      width: finalSize.width,
      height: finalSize.height
    )
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

    // Calculate interpolated frame
    let interpolatedFrame: CGRect
    if let sourceFrame = sourceFrame {
      interpolatedFrame = CGRect(
        x: finalFrame.origin.x + (sourceFrame.origin.x - finalFrame.origin.x) * progress + translation.x,
        y: finalFrame.origin.y + (sourceFrame.origin.y - finalFrame.origin.y) * progress + translation.y,
        width: finalFrame.width + (sourceFrame.width - finalFrame.width) * progress,
        height: finalFrame.height + (sourceFrame.height - finalFrame.height) * progress
      )
    } else {
      interpolatedFrame = CGRect(
        x: finalFrame.origin.x + translation.x,
        y: finalFrame.origin.y + translation.y,
        width: finalFrame.width,
        height: finalFrame.height
      )
    }

    imageView.frame = interpolatedFrame
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
}
