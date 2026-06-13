import SwiftUI
import UIKit

// MARK: - Window Cover Modifier

extension View {
  /// Presents a view in a separate UIWindow that covers the entire screen.
  /// Unlike fullScreenCover, this appears above all other content including sheets.
  func windowCover<Content: View>(
    isPresented: Binding<Bool>,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    modifier(WindowCoverModifier(isPresented: isPresented, sourceFrame: nil, coverContent: content))
  }

  /// Presents a view with a zoom transition from the source frame.
  func windowCover<Content: View>(
    isPresented: Binding<Bool>,
    sourceFrame: CGRect?,
    @ViewBuilder content: @escaping (_ sourceFrame: CGRect?) -> Content
  ) -> some View {
    modifier(
      WindowCoverModifier(
        isPresented: isPresented,
        sourceFrame: sourceFrame,
        coverContent: { content(sourceFrame) }
      ))
  }
}

// MARK: - Modifier

private struct WindowCoverModifier<CoverContent: View>: ViewModifier {
  @Binding var isPresented: Bool
  let sourceFrame: CGRect?
  @ViewBuilder var coverContent: () -> CoverContent

  @State private var windowManager: WindowCoverManager?
  @State private var hostScene: UIWindowScene?

  func body(content: Content) -> some View {
    content
      .trackWindowScene($hostScene)
      .onChange(of: isPresented) { _, newValue in
        if newValue {
          showWindow()
        } else {
          hideWindow()
        }
      }
  }

  private func showWindow() {
    guard windowManager == nil else { return }

    let manager = WindowCoverManager()
    windowManager = manager

    let wrappedContent = WindowCoverContentView(
      isPresented: $isPresented,
      content: coverContent
    )

    manager.show(content: wrappedContent, scene: hostScene)
  }

  private func hideWindow() {
    windowManager?.hide()
    windowManager = nil
  }
}

// MARK: - Content Wrapper

private struct WindowCoverContentView<Content: View>: View {
  @Binding var isPresented: Bool
  @ViewBuilder var content: () -> Content

  var body: some View {
    content()
      .environment(\.windowCoverDismiss, WindowCoverDismissAction {
        withAnimation(.spring(duration: 0.3)) {
          isPresented = false
        }
      })
  }
}

// MARK: - Window Manager

@MainActor
final class WindowCoverManager {
  private var window: UIWindow?

  /// Resolves the window scene to present in.
  ///
  /// Prefers the scene injected from the presenting view (correct under
  /// multi-window / Stage Manager), falling back to the first foreground-active
  /// scene when the injected one is unavailable.
  private func resolveScene(_ preferredScene: UIWindowScene?) -> UIWindowScene? {
    if let preferredScene, preferredScene.activationState != .unattached {
      return preferredScene
    }
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
  }

  func show<Content: View>(content: Content, scene: UIWindowScene? = nil) {
    guard let windowScene = resolveScene(scene) else {
      return
    }

    let window = UIWindow(windowScene: windowScene)
    window.backgroundColor = .clear
    window.windowLevel = .alert + 1

    let hostingController = UIHostingController(rootView: content)
    hostingController.view.backgroundColor = .clear
    hostingController.view.accessibilityViewIsModal = true
    window.rootViewController = hostingController

    self.window = window
    window.makeKeyAndVisible()
  }

  /// Presents the view controller in a new window.
  /// - Parameter scene: The window scene to present in. Falls back to the first
  ///   foreground-active scene when `nil`.
  /// - Returns: `true` if the window was presented, `false` if no active scene was available.
  @discardableResult
  func show(viewController: UIViewController, scene: UIWindowScene? = nil) -> Bool {
    guard let windowScene = resolveScene(scene) else {
      return false
    }

    let window = UIWindow(windowScene: windowScene)
    window.backgroundColor = .clear
    window.windowLevel = .alert + 1
    viewController.view.accessibilityViewIsModal = true
    window.rootViewController = viewController

    self.window = window
    window.makeKeyAndVisible()
    return true
  }

  func hide() {
    window?.isHidden = true
    window?.resignKey()
    window = nil
  }
}

// MARK: - Dismiss Environment

/// An action that dismisses the window cover.
struct WindowCoverDismissAction: Sendable {
  let action: @Sendable @MainActor () -> Void

  @MainActor
  func callAsFunction() {
    action()
  }
}

private struct WindowCoverDismissKey: EnvironmentKey {
  static let defaultValue = WindowCoverDismissAction {}
}

extension EnvironmentValues {
  /// An action that dismisses the current window cover.
  var windowCoverDismiss: WindowCoverDismissAction {
    get { self[WindowCoverDismissKey.self] }
    set { self[WindowCoverDismissKey.self] = newValue }
  }
}

// MARK: - Window Scene Reader

/// Reads the `UIWindowScene` of the presenting view's window.
///
/// Used to present the cover window in the same scene as the caller, which keeps
/// presentation correct under multi-window / Stage Manager.
struct WindowSceneReader: UIViewRepresentable {
  @Binding var scene: UIWindowScene?

  func makeUIView(context: Context) -> SceneTrackingView {
    let view = SceneTrackingView()
    view.onResolveScene = { resolved in
      // Avoid mutating state during view layout.
      DispatchQueue.main.async { scene = resolved }
    }
    return view
  }

  func updateUIView(_ uiView: SceneTrackingView, context: Context) {}

  final class SceneTrackingView: UIView {
    var onResolveScene: ((UIWindowScene?) -> Void)?

    override func didMoveToWindow() {
      super.didMoveToWindow()
      onResolveScene?(window?.windowScene)
    }
  }
}

extension View {
  /// Tracks the window scene of this view's window into the given binding.
  func trackWindowScene(_ scene: Binding<UIWindowScene?>) -> some View {
    background(WindowSceneReader(scene: scene))
  }
}
