import SwiftUI
import WebKit
import AppKit

// MARK: - WebContentView

/// Wraps a WKWebView directly using NSViewRepresentable.
/// The webView instance is passed in — it is never recreated on state changes.
struct WebContentView: NSViewRepresentable {

    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Intentionally empty — WKWebView manages its own state.
    }
}
