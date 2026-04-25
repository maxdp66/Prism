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
        let headerHeight: CGFloat = 82

        if let scrollView = webView.enclosingScrollView {
            let contentInset = NSEdgeInsets(top: headerHeight, left: 0, bottom: 0, right: 0)
            scrollView.contentInsets = contentInset
            scrollView.verticalScrollElasticity = .none
        }

        webView.additionalSafeAreaInsets = NSEdgeInsets(top: headerHeight, left: 0, bottom: 0, right: 0)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let headerHeight: CGFloat = 82
        
        if let scrollView = nsView.enclosingScrollView {
            let contentInset = NSEdgeInsets(top: headerHeight, left: 0, bottom: 0, right: 0)
            if scrollView.contentInsets.top != headerHeight {
                scrollView.contentInsets = contentInset
                scrollView.verticalScrollElasticity = .none
            }
        }
        
        let safeAreaInsets = NSEdgeInsets(top: headerHeight, left: 0, bottom: 0, right: 0)
        if nsView.additionalSafeAreaInsets.top != headerHeight {
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
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        let headerHeight: CGFloat = 82
        if let scrollView = webView.enclosingScrollView {
            scrollView.contentInsets = NSEdgeInsets(top: headerHeight, left: 0, bottom: 0, right: 0)
            scrollView.verticalScrollElasticity = .none
        }
        webView.additionalSafeAreaInsets = NSEdgeInsets(top: headerHeight, left: 0, bottom: 0, right: 0)

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let headerHeight: CGFloat = 82
        if let scrollView = webView.enclosingScrollView {
            scrollView.contentInsets = NSEdgeInsets(top: headerHeight, left: 0, bottom: 0, right: 0)
            scrollView.verticalScrollElasticity = .none
        }
        webView.additionalSafeAreaInsets = NSEdgeInsets(top: headerHeight, left: 0, bottom: 0, right: 0)
    }
}