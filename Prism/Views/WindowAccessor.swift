import SwiftUI
import AppKit

// MARK: - WindowAccessor

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                alignTrafficLights(for: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

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
