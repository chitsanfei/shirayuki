import SwiftUI
import WebKit

struct ManagedWebView: UIViewRepresentable {
    @ObservedObject var store: BrowserStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = store.webView
        store.attachMessageHandler(context.coordinator)
        webView.navigationDelegate = context.coordinator
        if webView.url == nil {
            store.loadInitialPage()
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let store: BrowserStore

        init(store: BrowserStore) {
            self.store = store
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                self.store.isLoading = true
                self.store.lastErrorMessage = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                self.store.isLoading = false
                self.store.lastErrorMessage = nil
                self.store.reapplyCurrentSettingsIfNeeded(retryDelays: [0.35, 1.1, 2.0])
                self.store.refreshLoginState()
                self.store.syncPathFromURL(webView.url)
                
                
                if self.store.isInReader {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    self.store.enterReaderMode()
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                Task { @MainActor in
                    self.store.isLoading = false
                }
                return
            }
            Task { @MainActor in
                self.store.isLoading = false
                self.store.lastErrorMessage = "加载失败：\((error as NSError).code) \(error.localizedDescription)"
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                Task { @MainActor in
                    self.store.isLoading = false
                }
                return
            }
            Task { @MainActor in
                self.store.isLoading = false
                self.store.lastErrorMessage = "连接失败：\((error as NSError).code) \(error.localizedDescription)"
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "shirayukiBridge",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            if type == "loginState", let loggedIn = body["loggedIn"] as? Bool {
                Task { @MainActor in
                    self.store.isLoggedIn = loggedIn
                }
            } else if type == "pathChange", let path = body["path"] as? String {
                Task { @MainActor in
                    let wasInReader = self.store.isInReader
                    self.store.syncPathFromPage(path)
                    let isInReader = self.store.isInReader
                    
                    
                    if !wasInReader && isInReader {
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            self.store.enterReaderMode()
                        }
                    }
                }
            } else if type == "startReadingTap" {
                Task { @MainActor in
                    self.store.isLoading = true
                    self.store.lastErrorMessage = nil
                }
            }
        }
    }
}
