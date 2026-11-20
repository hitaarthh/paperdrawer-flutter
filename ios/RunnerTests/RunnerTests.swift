import Testing
import UIKit
@testable import native_liquid_glass

@MainActor
struct RunnerTests {

  @Test func glassAcceptsTouchesAsSoonAsItReturns() {
    let glass = UIView(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
    let observer = GlassSuppressObserver(view: glass)
    let point = CGPoint(x: 24, y: 24)

    observer.setRouteSuppressed(true)
    #expect(!glass.isUserInteractionEnabled)
    #expect(glass.hitTest(point, with: nil) == nil)

    observer.setRouteSuppressed(false)
    #expect(glass.isUserInteractionEnabled)
    #expect(glass.hitTest(point, with: nil) === glass)
  }

  @Test func glassStaysInactiveUntilBothOverlaysClear() {
    let glass = UIView()
    let observer = GlassSuppressObserver(view: glass)
    let notifications = NotificationCenter.default
    defer { notifications.post(name: .liquidGlassUnsuppress, object: nil) }

    observer.setRouteSuppressed(true)
    notifications.post(name: .liquidGlassSuppress, object: nil)
    observer.setRouteSuppressed(false)
    #expect(!glass.isUserInteractionEnabled)

    notifications.post(name: .liquidGlassUnsuppress, object: nil)
    #expect(glass.isUserInteractionEnabled)
  }
}
