import CoreGraphics
import Testing

@testable import OmniWM

@Suite struct WindowCompositorBackendTests {
    @Test func flipStartsAtOriginalFrameAndEndsAtIdentity() {
        let from = CGRect(x: 10, y: 20, width: 100, height: 80)
        let to = CGRect(x: 210, y: 40, width: 200, height: 160)
        guard let plan = WindowTransitionPlan(from: from, to: to) else {
            Issue.record("Expected valid geometry")
            return
        }
        let start = plan.effect(at: 0)
        #expect(start.translation == CGPoint(x: -200, y: -20))
        #expect(start.scale == CGSize(width: 0.5, height: 0.5))
        #expect(plan.effect(at: 1) == .identity)
    }

    @Test func clampsInvalidProgressAndOpacity() {
        guard let plan = WindowTransitionPlan(
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 100, y: 0, width: 100, height: 100)
        ) else {
            Issue.record("Expected valid geometry")
            return
        }
        #expect(plan.effect(at: -5).translation.x == -100)
        #expect(plan.effect(at: 5) == .identity)
        #expect(plan.effect(at: .nan) == .identity)
        #expect(plan.effect(at: 1, opacity: 42).opacity == 1)
        #expect(plan.effect(at: 1, opacity: -2).opacity == 0)
    }

    @Test func rejectsInvalidWindowGeometry() {
        #expect(WindowTransitionPlan(
            from: .zero,
            to: CGRect(x: 0, y: 0, width: 100, height: 100)
        ) == nil)
        #expect(WindowTransitionPlan(
            from: CGRect(x: CGFloat.infinity, y: 0, width: 100, height: 100),
            to: CGRect(x: 0, y: 0, width: 100, height: 100)
        ) == nil)
    }

    @Test func retargetsFromVisibleFrame() {
        guard let first = WindowTransitionPlan(
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 100, y: 0, width: 100, height: 100)
        ), let second = first.retarget(
            fromDisplayedFrame: CGRect(x: 40, y: 0, width: 100, height: 100),
            to: CGRect(x: 200, y: 0, width: 100, height: 100)
        ) else {
            Issue.record("Expected valid geometry")
            return
        }
        #expect(second.effect(at: 0).translation.x == -160)
        #expect(second.effect(at: 1) == .identity)
    }
}
