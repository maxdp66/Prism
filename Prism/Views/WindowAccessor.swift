import SwiftUI
import AppKit

// MARK: - WindowDragBlocker

/// Prevents AppKit from treating this view's area as a title-bar drag target.
/// Without this, fullSizeContentView windows drag the window before SwiftUI
/// gesture recognizers have a chance to fire.
struct WindowDragBlocker: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NonDraggableView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private class NonDraggableView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
    }
}

// MARK: - WindowDragHandle

/// Pure-AppKit window drag handle. SwiftUI DragGesture is unreliable in the
/// title-bar area of fullSizeContentView windows; using mouseDown/mouseDragged
/// with setFrameOrigin works unconditionally regardless of window.isMovable.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { HandleView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private class HandleView: NSView {
        private var startMouseLocation: NSPoint = .zero
        private var startWindowOrigin: NSPoint = .zero

        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            startMouseLocation = NSEvent.mouseLocation
            startWindowOrigin = window?.frame.origin ?? .zero
        }

        override func mouseDragged(with event: NSEvent) {
            let current = NSEvent.mouseLocation
            let dx = current.x - startMouseLocation.x
            let dy = current.y - startMouseLocation.y
            window?.setFrameOrigin(NSPoint(x: startWindowOrigin.x + dx,
                                           y: startWindowOrigin.y + dy))
        }
    }
}

// MARK: - WindowAccessor

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Ensure window is not movable by background (for tab dragging)
                window.isMovable = false
                alignTrafficLights(for: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-ensure movable setting on updates
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.isMovable = false
            }
        }
    }

    private func alignTrafficLights(for window: NSWindow) {
        // Define your desired Y-offset (distance from the top)
        // Adjust '14' until it perfectly aligns with your text center
        let verticalOffset: CGFloat = 14

        let buttons = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton)
        ]

        for button in buttons {
            if let button = button, let superview = button.superview {
                var frame = button.frame
                // superview.frame.height is the total height of the titlebar area
                frame.origin.y = superview.frame.height - frame.height - verticalOffset
                button.setFrameOrigin(frame.origin)
            }
        }
    }
}
