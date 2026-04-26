import SwiftUI
import WebKit
import AppKit

struct WebContentView: NSViewRepresentable {

    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        if let scrollView = webView.enclosingScrollView {
            scrollView.drawsBackground = true
            scrollView.backgroundColor = NSColor.windowBackgroundColor
            scrollView.wantsLayer = true
            scrollView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }

        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

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

