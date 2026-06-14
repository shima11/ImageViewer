import Testing
import CoreGraphics
@testable import ImageViewer

@Suite("TransitionState.allows")
struct TransitionStateAllowsTests {

  // MARK: - Allowed transitions

  @Test("appear animation completes: appearing -> presented")
  func appearingToPresented() {
    #expect(TransitionState.allows(.appearing, to: .presented))
  }

  @Test("pan begins: presented -> interactive")
  func presentedToInteractive() {
    #expect(TransitionState.allows(.presented, to: .interactive))
  }

  @Test("progress update: interactive -> interactive")
  func interactiveToInteractive() {
    #expect(TransitionState.allows(.interactive, to: .interactive))
  }

  @Test("pan cancelled, rebound: interactive -> presented")
  func interactiveToPresented() {
    #expect(TransitionState.allows(.interactive, to: .presented))
  }

  @Test("pan crossed threshold: interactive -> dismissing")
  func interactiveToDismissing() {
    #expect(TransitionState.allows(.interactive, to: .dismissing))
  }

  @Test("dismiss() / background tap: presented -> dismissing")
  func presentedToDismissing() {
    #expect(TransitionState.allows(.presented, to: .dismissing))
  }

  // MARK: - dismissing is terminal (double-dismiss prevention, #66)

  @Test("dismissing is terminal: every transition out of it is rejected", arguments: [
    TransitionState.Kind.appearing,
    .presented,
    .interactive,
    .dismissing,
  ])
  func dismissingIsTerminal(to: TransitionState.Kind) {
    #expect(!TransitionState.allows(.dismissing, to: to))
  }

  // MARK: - Rejected transitions

  @Test("appearing cannot jump to interactive")
  func appearingToInteractiveRejected() {
    #expect(!TransitionState.allows(.appearing, to: .interactive))
  }

  @Test("appearing cannot jump straight to dismissing")
  func appearingToDismissingRejected() {
    #expect(!TransitionState.allows(.appearing, to: .dismissing))
  }

  @Test("appearing cannot re-enter appearing")
  func appearingToAppearingRejected() {
    #expect(!TransitionState.allows(.appearing, to: .appearing))
  }

  @Test("presented cannot go back to appearing")
  func presentedToAppearingRejected() {
    #expect(!TransitionState.allows(.presented, to: .appearing))
  }

  @Test("presented cannot re-enter presented")
  func presentedToPresentedRejected() {
    #expect(!TransitionState.allows(.presented, to: .presented))
  }

  @Test("interactive cannot go back to appearing")
  func interactiveToAppearingRejected() {
    #expect(!TransitionState.allows(.interactive, to: .appearing))
  }

  // MARK: - kind derivation

  @Test("kind ignores associated values")
  func kindIgnoresAssociatedValues() {
    let a = TransitionState.interactive(progress: 0.1, translation: .zero)
    let b = TransitionState.interactive(progress: 0.9, translation: CGPoint(x: 10, y: 20))
    #expect(a.kind == b.kind)
    #expect(a.kind == .interactive)
  }
}
