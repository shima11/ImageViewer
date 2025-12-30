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

  func body(content: Content) -> some View {
    content
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

    manager.show(content: wrappedContent)
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

  func show<Content: View>(content: Content) {
    guard
      let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })
    else {
      return
    }

    let window = PassthroughWindow(windowScene: windowScene)
    window.backgroundColor = .clear
    window.windowLevel = .alert + 1

    let hostingController = UIHostingController(rootView: content)
    hostingController.view.backgroundColor = .clear
    window.rootViewController = hostingController

    self.window = window
    window.makeKeyAndVisible()
  }

  func show(viewController: UIViewController) {
    guard
      let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })
    else {
      return
    }

    let window = PassthroughWindow(windowScene: windowScene)
    window.backgroundColor = .clear
    window.windowLevel = .alert + 1
    window.rootViewController = viewController

    self.window = window
    window.makeKeyAndVisible()
  }

  func hide() {
    window?.isHidden = true
    window?.resignKey()
    window = nil
  }
}

// MARK: - Passthrough Window

private final class PassthroughWindow: UIWindow {
  // No custom hitTest - allow all touches to be handled normally
}

// MARK: - Dismiss Environment

/// An action that dismisses the window cover.
public struct WindowCoverDismissAction: Sendable {
  let action: @Sendable @MainActor () -> Void

  @MainActor
  public func callAsFunction() {
    action()
  }
}

private struct WindowCoverDismissKey: EnvironmentKey {
  static let defaultValue = WindowCoverDismissAction {}
}

extension EnvironmentValues {
  /// An action that dismisses the current window cover.
  public var windowCoverDismiss: WindowCoverDismissAction {
    get { self[WindowCoverDismissKey.self] }
    set { self[WindowCoverDismissKey.self] = newValue }
  }
}
