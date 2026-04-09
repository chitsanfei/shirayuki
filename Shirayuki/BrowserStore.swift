import Foundation
import WebKit
import Combine

struct WebRuntimeSettings {
    var darkModeEnabled: Bool
    var videoBlockEnabled: Bool
}

final class BrowserStore: NSObject, ObservableObject {
    @Published var isLoggedIn = false
    @Published var isInReader = false
    @Published var selectedTab: ShirayukiTab = .home
    @Published var isLoading = false
    @Published var lastErrorMessage: String?

    private(set) var webView: WKWebView
    private let baseURL = URL(string: "https://manhuabika.com")!
    private let skipWebLoadForUITest: Bool
    private var currentSettings: WebRuntimeSettings
    private var hasAppliedRuntimeSettings = false

    init(settings: WebRuntimeSettings) {
        self.skipWebLoadForUITest = ProcessInfo.processInfo.arguments.contains("UITEST_SKIP_WEB_LOAD")
        self.currentSettings = settings

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all

        let userContentController = WKUserContentController()
        userContentController.addUserScript(
            WKUserScript(
                source: BrowserStore.nativeScript(settings: settings),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )
        config.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        super.init()

        if ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_LOGGED_IN") {
            isLoggedIn = true
        }
        if ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_READER") {
            isInReader = true
        }
    }

    func apply(settings: WebRuntimeSettings) {
        currentSettings = settings
        hasAppliedRuntimeSettings = true
        let backgroundColor: UIColor = settings.darkModeEnabled ? .black : .systemBackground
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor

        webView.evaluateJavaScript("""
        window.__shirayukiDarkModeEnabled = \(settings.darkModeEnabled ? "true" : "false");
        window.__shirayukiVideoBlockEnabled = \(settings.videoBlockEnabled ? "true" : "false");
        window.__shirayukiApplyNativeTweaks && window.__shirayukiApplyNativeTweaks();
        """)
    }

    func reapplyCurrentSettingsIfNeeded() {
        guard hasAppliedRuntimeSettings else { return }
        apply(settings: currentSettings)
    }

    func loadInitialPage() {
        lastErrorMessage = nil
        guard !skipWebLoadForUITest else { return }
        webView.load(URLRequest(url: baseURL))
    }

    func navigate(to tab: ShirayukiTab) {
        lastErrorMessage = nil
        selectedTab = tab
        guard let url = URL(string: tab.path, relativeTo: baseURL) else { return }
        webView.load(URLRequest(url: url))
    }

    func refreshLoginState() {
        webView.evaluateJavaScript("(function(){ return !!localStorage.getItem('token'); })();") { [weak self] result, _ in
            guard let loggedIn = result as? Bool else { return }
            DispatchQueue.main.async {
                self?.isLoggedIn = loggedIn
            }
        }
    }

    func syncPathFromURL(_ url: URL?) {
        syncPathFromPage(url?.path ?? "/")
    }

    func syncPathFromPage(_ rawPath: String) {
        let path = ReaderRoute.normalized(rawPath)
        isInReader = ReaderRoute.isReaderPath(path)
        if let tab = ReaderRoute.tab(for: path) {
            selectedTab = tab
        }
    }

    func exitReader() {
        webView.evaluateJavaScript("""
        (function() {
          if (window.history.length > 1) {
            window.history.back();
            return true;
          }
          return false;
        })();
        """) { [weak self] result, _ in
            let didBack = (result as? Bool) ?? false
            if !didBack {
                self?.navigate(to: .home)
            }
        }
    }

    func goBack() {
        webView.evaluateJavaScript("""
        (function() {
          if (typeof window.__shirayukiGoBack === 'function') {
            return window.__shirayukiGoBack();
          }
          return 'none';
        })();
        """) { [weak self] result, _ in
            let mode = (result as? String) ?? "none"
            if mode == "none" {
                if self?.webView.canGoBack == true {
                    self?.webView.goBack()
                    return
                }
                self?.navigate(to: .home)
            }
        }
    }

    func clearCache(completion: @escaping (Result<Void, Error>) -> Void) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: types) { records in
            WKWebsiteDataStore.default().removeData(ofTypes: types, for: records) {
                URLCache.shared.removeAllCachedResponses()
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                    self.isInReader = false
                    self.selectedTab = .home
                    self.loadInitialPage()
                    completion(.success(()))
                }
            }
        }
    }

    func attachMessageHandler(_ handler: WKScriptMessageHandler) {
        let uc = webView.configuration.userContentController
        uc.removeScriptMessageHandler(forName: "shirayukiBridge")
        uc.add(handler, name: "shirayukiBridge")
    }

    private static func nativeScript(settings: WebRuntimeSettings) -> String {
        """
        (function() {
          if (window.__shirayukiInjected) return;
          window.__shirayukiInjected = true;
          window.__shirayukiDarkModeEnabled = \(settings.darkModeEnabled ? "true" : "false");
          window.__shirayukiVideoBlockEnabled = \(settings.videoBlockEnabled ? "true" : "false");

          const navWords = ['主頁', '主页', '分类', '遊戲', '游戏', '個人中心', '个人中心', '功能', 'categories', 'profile', 'home', 'search'];
          const topNavHints = ['back', 'menu', 'search', 'more', 'categories', 'profile', 'home', '返回', '搜索', '更多', '菜单', '目錄', '分類'];

          const isBottomFixed = (el) => {
            const style = window.getComputedStyle(el);
            if (!style) return false;
            const p = style.position;
            const b = parseInt(style.bottom || '0', 10);
            return (p === 'fixed' || p === 'sticky') && !Number.isNaN(b) && b <= 44;
          };

          const isTopFixed = (el) => {
            const style = window.getComputedStyle(el);
            if (!style) return false;
            const p = style.position;
            const t = parseInt(style.top || '0', 10);
            return (p === 'fixed' || p === 'sticky') && !Number.isNaN(t) && t <= 96;
          };

          const hideNode = (el) => {
            if (!el) return;
            el.style.setProperty('display', 'none', 'important');
            el.setAttribute('data-shirayuki-hidden', '1');
          };

          const hideOriginalNav = () => {
            const all = Array.from(document.querySelectorAll('a, button, div, span, nav'));
            all.forEach((el) => {
              const text = (el.textContent || '').replace(/\\s+/g, '');
              if (!text) return;
              if (!navWords.some((word) => text.includes(word))) return;
              if (isBottomFixed(el) || (el.closest('nav') && isBottomFixed(el.closest('nav')))) {
                hideNode(el);
                const parent = el.parentElement;
                if (parent && isBottomFixed(parent)) {
                  hideNode(parent);
                }
              }
            });

            const topCandidates = Array.from(document.querySelectorAll('header, nav, div, section, a, button'));
            topCandidates.forEach((el) => {
              const text = ((el.textContent || '') + ' ' + (el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '')).toLowerCase();
              const iconText = `${el.id || ''} ${(el.className || '').toString()}`.toLowerCase();
              const looksLikeTopNav = topNavHints.some((word) => text.includes(word) || iconText.includes(word));
              const hasControls = el.querySelectorAll?.('button,a,svg').length ?? 0;
              const parent = el.parentElement;
              if (isTopFixed(el) && (looksLikeTopNav || hasControls >= 2)) {
                hideNode(el);
              }
              if (parent && isTopFixed(parent) && looksLikeTopNav) {
                hideNode(parent);
              }
            });
          };

          window.__shirayukiGoBack = () => {
            const candidates = Array.from(document.querySelectorAll('a, button, [role="button"]'));
            const isBackLike = (el) => {
              const text = ((el.textContent || '') + ' ' + (el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '')).toLowerCase();
              const meta = `${el.id || ''} ${(el.className || '').toString()}`.toLowerCase();
              return text.includes('返回') ||
                text.includes('back') ||
                text.includes('go back') ||
                text.includes('上一页') ||
                meta.includes('back') ||
                meta.includes('chevron-left') ||
                meta.includes('arrow-left');
            };

            const target = candidates.find(isBackLike);
            if (target) {
              target.click();
              return 'dom';
            }

            try {
              if (window.history.length > 1) {
                window.history.back();
                return 'history';
              }
            } catch (e) {}

            try {
              if (window.navigation && typeof window.navigation.back === 'function') {
                window.navigation.back();
                return 'navigation';
              }
            } catch (e) {}

            return 'none';
          };

          const applyDarkMode = () => {
            const id = '__shirayukiDarkStyle';
            const existing = document.getElementById(id);
            if (!window.__shirayukiDarkModeEnabled) {
              if (existing) existing.remove();
              return;
            }
            if (existing) return;
            const style = document.createElement('style');
            style.id = id;
            style.textContent = `
              html, body, #root { background: #0f1117 !important; color: #dce3ee !important; }
              body *:not(img):not(svg):not(picture):not(canvas):not(video):not(source) {
                background-color: #121621 !important;
                color: #dce3ee !important;
                border-color: rgba(220, 227, 238, 0.18) !important;
              }
              img, picture, canvas, svg { filter: none !important; }
            `;
            document.head.appendChild(style);
          };

          const neutralizeVideo = (video) => {
            if (!video) return;
            try {
              video.pause();
              video.autoplay = false;
              video.muted = true;
              video.loop = false;
              video.controls = false;
              video.playsInline = true;
              video.setAttribute('playsinline', 'true');
              video.setAttribute('webkit-playsinline', 'true');
              video.removeAttribute('autoplay');
              video.removeAttribute('src');
              video.disablePictureInPicture = true;
              video.controlsList = 'nofullscreen nodownload noplaybackrate';
              video.querySelectorAll('source').forEach((s) => s.removeAttribute('src'));
              video.load?.();
              video.style.setProperty('display', 'none', 'important');
              video.style.setProperty('visibility', 'hidden', 'important');
              video.style.setProperty('pointer-events', 'none', 'important');
            } catch (e) {}
          };

          const blockVideos = () => {
            if (!window.__shirayukiVideoBlockEnabled) return;
            document.querySelectorAll('video').forEach(neutralizeVideo);
          };

          const installVideoGuards = () => {
            if (window.__shirayukiVideoGuardInstalled) return;
            window.__shirayukiVideoGuardInstalled = true;

            const blockFullscreen = function() { return Promise.reject(new Error('fullscreen blocked')); };

            try { HTMLVideoElement.prototype.play = function() { neutralizeVideo(this); return Promise.resolve(); }; } catch (e) {}
            try { HTMLVideoElement.prototype.requestFullscreen = blockFullscreen; } catch (e) {}
            try { HTMLVideoElement.prototype.webkitEnterFullscreen = function() {}; } catch (e) {}
            try { HTMLVideoElement.prototype.webkitRequestFullscreen = blockFullscreen; } catch (e) {}
            try { Element.prototype.requestFullscreen = blockFullscreen; } catch (e) {}

            const observer = new MutationObserver((mutations) => {
              if (!window.__shirayukiVideoBlockEnabled) return;
              mutations.forEach((mutation) => {
                mutation.addedNodes.forEach((node) => {
                  if (!(node instanceof Element)) return;
                  if (node.tagName === 'VIDEO') {
                    neutralizeVideo(node);
                  }
                  node.querySelectorAll?.('video').forEach(neutralizeVideo);
                });
              });
            });

            observer.observe(document.documentElement, { childList: true, subtree: true });
          };

          const clearShirayukiHiddenNodes = () => {
            document.querySelectorAll('[data-shirayuki-hidden="1"]').forEach((el) => {
              el.style.removeProperty('display');
              el.removeAttribute('data-shirayuki-hidden');
            });
          };

          const removeDarkModeStyle = () => {
            const style = document.getElementById('__shirayukiDarkStyle');
            if (style) style.remove();
          };

          const isReaderRoute = () => (window.location.pathname || '').includes('/comic/reader/');
          const isLoggedIn = () => {
            try {
              return !!localStorage.getItem('token');
            } catch (e) {
              return false;
            }
          };

          const syncLogin = () => {
            try {
              const loggedIn = isLoggedIn();
              window.webkit?.messageHandlers?.shirayukiBridge?.postMessage({ type: 'loginState', loggedIn });
            } catch (e) {}
          };

          const syncPath = () => {
            try {
              window.webkit?.messageHandlers?.shirayukiBridge?.postMessage({
                type: 'pathChange',
                path: window.location.pathname || '/'
              });
            } catch (e) {}
          };

          const installRouteHooks = () => {
            if (window.__shirayukiRouteHooked) return;
            window.__shirayukiRouteHooked = true;
            const rawPush = history.pushState;
            const rawReplace = history.replaceState;
            history.pushState = function() {
              const result = rawPush.apply(this, arguments);
              setTimeout(syncPath, 0);
              return result;
            };
            history.replaceState = function() {
              const result = rawReplace.apply(this, arguments);
              setTimeout(syncPath, 0);
              return result;
            };
            window.addEventListener('popstate', syncPath);
            window.addEventListener('hashchange', syncPath);
          };

          const installStartReadingFallback = () => {
            if (window.__shirayukiStartReaderHooked) return;
            window.__shirayukiStartReaderHooked = true;
            document.addEventListener('click', (event) => {
              const trigger = event.target && event.target.closest
                ? event.target.closest('a,button,[role="button"]')
                : null;
              if (!trigger) return;
              const text = (trigger.textContent || '').replace(/\\s+/g, '').toLowerCase();
              const isStartText = text.includes('开始阅读') || text.includes('開始閱讀') || text.includes('startreading');
              if (!isStartText) return;

              try {
                window.webkit?.messageHandlers?.shirayukiBridge?.postMessage({ type: 'startReadingTap' });
              } catch (e) {}

              const href = trigger.getAttribute('href') || trigger.closest('a')?.getAttribute('href');
              if (href && href.includes('/comic/reader/')) {
                setTimeout(() => {
                  if (!window.location.pathname.includes('/comic/reader/')) {
                    window.location.assign(href);
                  }
                }, 120);
              }
            }, true);
          };

          window.__shirayukiApplyNativeTweaks = () => {
            syncPath();
            const loggedIn = isLoggedIn();

            if (!loggedIn) {
              clearShirayukiHiddenNodes();
              removeDarkModeStyle();
              return;
            }

            if (isReaderRoute()) {
              clearShirayukiHiddenNodes();
              removeDarkModeStyle();
              blockVideos();
              return;
            }
            hideOriginalNav();
            applyDarkMode();
            blockVideos();
          };

          installRouteHooks();
          installStartReadingFallback();
          installVideoGuards();
          window.addEventListener('storage', syncLogin);

          setInterval(() => {
            window.__shirayukiApplyNativeTweaks();
            syncLogin();
          }, 1000);

          setTimeout(() => {
            window.__shirayukiApplyNativeTweaks();
            syncLogin();
          }, 300);
        })();
        """
    }
}
