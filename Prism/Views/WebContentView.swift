import SwiftUI
import WebKit
import AppKit

struct WebContentView: NSViewRepresentable {

    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        if let scrollView = webView.enclosingScrollView {
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
            scrollView.wantsLayer = true
            scrollView.layer?.backgroundColor = CGColor.clear
        }

        webView.wantsLayer = true
        webView.layer?.backgroundColor = CGColor.clear

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let newInsets = NSEdgeInsets(top: 72, left: 0, bottom: 0, right: 0)
        if nsView.additionalSafeAreaInsets.top != newInsets.top ||
           nsView.additionalSafeAreaInsets.left != newInsets.left ||
           nsView.additionalSafeAreaInsets.bottom != newInsets.bottom ||
           nsView.additionalSafeAreaInsets.right != newInsets.right {
            nsView.additionalSafeAreaInsets = newInsets
        }
    }
}

struct WebContentContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = CGColor.clear
        container.clipsToBounds = false

        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor, constant: 72),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}