import CoreGraphics
import Foundation

// Opt-in window-surface effects; this interface does not depend on Dock injection.
// The existing Accessibility window movement remains the fallback when a backend
// is not available or rejects a particular window.

enum WindowCompositorError: Error {
    case unavailable
}

struct WindowVisualEffect: Equatable {
    /// Translation in the target window's coordinate space, in screen points.
    let translation: CGPoint
    /// Scale anchored at the target window's upper-left corner.
    let scale: CGSize
    /// The compositor should clamp opacity to 0...1 before applying it.
    let opacity: CGFloat

    static let identity = WindowVisualEffect(
        translation: .zero,
        scale: CGSize(width: 1, height: 1),
        opacity: 1
    )
}

/// Plans a FLIP-style transition: commit the final AX frame, then visually
/// display the old frame and animate its compositor transform to identity.
/// Only mathematical planning lives here. SkyLight coordinates, permissions,
/// hit testing, and cleanup belong to the concrete backend.
struct WindowTransitionPlan {
    let from: CGRect
    let to: CGRect

    init?(from: CGRect, to: CGRect) {
        guard Self.valid(from), Self.valid(to) else { return nil }
        self.from = from
        self.to = to
    }

    func effect(at progress: CGFloat, opacity: CGFloat = 1) -> WindowVisualEffect {
        // Non-finite progress must never reach a private compositor API.
        let t = progress.isFinite ? min(1, max(0, progress)) : 1
        let alpha = opacity.isFinite ? min(1, max(0, opacity)) : 1
        let x = from.minX + (to.minX - from.minX) * t
        let y = from.minY + (to.minY - from.minY) * t
        let width = from.width + (to.width - from.width) * t
        let height = from.height + (to.height - from.height) * t
        return WindowVisualEffect(
            translation: CGPoint(x: x - to.minX, y: y - to.minY),
            scale: CGSize(width: width / to.width, height: height / to.height),
            opacity: alpha
        )
    }

    /// Use the currently displayed frame when re-targeting an interrupted move.
    func retarget(fromDisplayedFrame frame: CGRect, to newTarget: CGRect) -> WindowTransitionPlan? {
        WindowTransitionPlan(from: frame, to: newTarget)
    }

    private static func valid(_ rect: CGRect) -> Bool {
        rect.minX.isFinite && rect.minY.isFinite &&
            rect.width.isFinite && rect.height.isFinite &&
            rect.width > 0 && rect.height > 0
    }
}

@MainActor
protocol WindowCompositorBackend: AnyObject {
    var isAvailable: Bool { get }
    /// Apply the effect to an *existing real window*; never to a captured image.
    func apply(_ effect: WindowVisualEffect, to windowID: CGWindowID) throws
    /// Must restore identity when the effect completes or the helper disconnects.
    func reset(windowID: CGWindowID)
}

/// SIP-compatible, explicitly unsupported backend. Keep this as the safe
/// default until runtime checks prove a private backend can be used.
@MainActor
final class UnavailableWindowCompositorBackend: WindowCompositorBackend {
    var isAvailable: Bool { false }

    func apply(_ effect: WindowVisualEffect, to windowID: CGWindowID) throws {
        throw WindowCompositorError.unavailable
    }

    func reset(windowID: CGWindowID) {}
}
