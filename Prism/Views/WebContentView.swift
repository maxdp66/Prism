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

        applyInsets(to: webView)
        
        return webView
    }
    
    private func applyInsets(to webView: WKWebView) {
        let topPadding: CGFloat = 72
        
        if let scrollView = webView.enclosingScrollView {
            let contentInset = NSEdgeInsets(top: topPadding, left: 0, bottom: 0, right: 0)
            scrollView.contentInsets = contentInset
            scrollView.verticalScrollElasticity = .none
        }
        
        webView.additionalSafeAreaInsets = NSEdgeInsets(top: topPadding, left: 0, bottom: 0, right: 0)
        
        webView.evaluateJavaScript("window.scrollTo(0, 0);") { _, _ in }
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let topPadding: CGFloat = 72
        
        if let scrollView = nsView.enclosingScrollView {
            let contentInset = NSEdgeInsets(top: topPadding, left: 0, bottom: 0, right: 0)
            if scrollView.contentInsets.top != topPadding {
                scrollView.contentInsets = contentInset
                scrollView.verticalScrollElasticity = .none
            }
        }
        
        let safeAreaInsets = NSEdgeInsets(top: topPadding, left: 0, bottom: 0, right: 0)
        if nsView.additionalSafeAreaInsets.top != topPadding {
            nsView.additionalSafeAreaInsets = safeAreaInsets
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
            webView.topAnchor.constraint(equalTo: container.topAnchor, constant: 0),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}