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
            DispatchQueue.main.async {
                self.store.isLoading = true
                self.store.lastErrorMessage = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.store.isLoading = false
                self.store.lastErrorMessage = nil
            }
            store.reapplyCurrentSettingsIfNeeded(retryDelays: [0.35, 1.1, 2.0])
            store.refreshLoginState()
            store.syncPathFromURL(webView.url)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                DispatchQueue.main.async {
                    self.store.isLoading = false
                }
                return
            }
            DispatchQueue.main.async {
                self.store.isLoading = false
                self.store.lastErrorMessage = "加载失败：\((error as NSError).code) \(error.localizedDescription)"
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                DispatchQueue.main.async {
                    self.store.isLoading = false
                }
                return
            }
            DispatchQueue.main.async {
                self.store.isLoading = false
                self.store.lastErrorMessage = "连接失败：\((error as NSError).code) \(error.localizedDescription)"
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "shirayukiBridge",
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            if type == "loginState", let loggedIn = body["loggedIn"] as? Bool {
                DispatchQueue.main.async {
                    self.store.isLoggedIn = loggedIn
                }
            } else if type == "pathChange", let path = body["path"] as? String {
                DispatchQueue.main.async {
                    self.store.syncPathFromPage(path)
                }
            } else if type == "startReadingTap" {
                DispatchQueue.main.async {
                    self.store.isLoading = true
                    self.store.lastErrorMessage = nil
                }
            }
        }
    }
}
