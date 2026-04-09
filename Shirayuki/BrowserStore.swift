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

        // Lightweight fallback: one-shot style upsert without mutation loops.
        webView.evaluateJavaScript("""
        (function() {
          const darkEnabled = \(settings.darkModeEnabled ? "true" : "false");
          const pathLower = (window.location.pathname || '').toLowerCase();
          const isReader = pathLower.includes('/comic/reader/');
          const isAuthRoute = pathLower === '/' ||
            pathLower.includes('/login') ||
            pathLower.includes('/register') ||
            pathLower.includes('/signin') ||
            pathLower.includes('/signup');
          const upsertStyle = (id, cssText) => {
            let node = document.getElementById(id);
            if (!node) {
              node = document.createElement('style');
              node.id = id;
              (document.head || document.documentElement).appendChild(node);
            }
            if (node.textContent !== cssText) node.textContent = cssText;
          };
          const removeStyle = (id) => {
            const node = document.getElementById(id);
            if (node) node.remove();
          };

          upsertStyle('__shirayukiForceHideNav', `
            .mobile-permanent-nav,
            .mobile-permanent-nav *,
            .mobile-tab-item,
            [class*="mobile-permanent-nav"] {
              display: none !important;
              visibility: hidden !important;
              pointer-events: none !important;
              opacity: 0 !important;
              height: 0 !important;
              min-height: 0 !important;
              max-height: 0 !important;
            }
            header [aria-label*="search" i],
            header [title*="search" i],
            header [aria-label*="back" i],
            header [title*="back" i],
            header [aria-label*="menu" i],
            header [title*="menu" i],
            header [aria-label*="more" i],
            header [title*="more" i],
            [class*="header"] [aria-label*="search" i],
            [class*="header"] [aria-label*="menu" i],
            [class*="header"] [aria-label*="more" i],
            [class*="header"] [title*="search" i],
            [class*="header"] [aria-label*="back" i],
            [class*="header"] [title*="back" i],
            [class*="header"] [title*="menu" i],
            [class*="header"] [title*="more" i],
            [class*="top"] [aria-label*="search" i],
            [class*="top"] [aria-label*="menu" i],
            [class*="top"] [aria-label*="more" i],
            [class*="top"] [title*="search" i],
            [class*="top"] [aria-label*="back" i],
            [class*="top"] [title*="back" i],
            [class*="top"] [title*="menu" i],
            [class*="top"] [title*="more" i],
            [class*="back-button"],
            [class*="search-button"],
            [class*="menu-button"],
            [class*="more-button"],
            [class*="hamburger"],
            [class*="nav-search"],
            [class*="nav-menu"] {
              display: none !important;
              visibility: hidden !important;
              pointer-events: none !important;
              opacity: 0 !important;
            }
            body { padding-bottom: 0 !important; }
          `);

          if (!isReader && !isAuthRoute && darkEnabled) {
            upsertStyle('__shirayukiForceDark', `
              html, body, #root, #app, #__next, main, .app, .container, .layout, .page, .content, .wrapper {
                background: #0f1117 !important;
                background-color: #0f1117 !important;
                color: #dce3ee !important;
                margin: 0 !important;
                min-height: 100vh !important;
              }
              body, #root, #app, #__next { overflow-x: hidden !important; }
              body *:not(img):not(svg):not(picture):not(canvas):not(video):not(source):not(path):not(use) {
                background-color: #121621 !important;
                color: #dce3ee !important;
                border-color: rgba(220, 227, 238, 0.18) !important;
              }
            `);
          } else {
            removeStyle('__shirayukiForceDark');
          }
        })();
        """)
    }

    func reapplyCurrentSettingsIfNeeded(retryDelays: [TimeInterval] = []) {
        guard hasAppliedRuntimeSettings else { return }
        apply(settings: currentSettings)
        for delay in retryDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.hasAppliedRuntimeSettings else { return }
                self.apply(settings: self.currentSettings)
            }
        }
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
        reapplyCurrentSettingsIfNeeded(retryDelays: [0.25, 0.9, 1.8])
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
        if isInReader {
            isLoading = false
            lastErrorMessage = nil
        }
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
        if webView.canGoBack {
            webView.goBack()
            return
        }

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

          const navWords = ['主頁', '主页', '分类', '遊戲', '游戏', '個人中心', '个人中心', '功能', 'categories', 'profile', 'home', 'search', '首页', '我的'];
          const topNavHints = ['back', 'menu', 'search', 'more', '返回', '搜索', '更多', '菜单', '目錄', '分類'];

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
            // Site-specific: this is the exact mobile permanent tab bar.
            document.querySelectorAll('.mobile-permanent-nav').forEach((el) => hideNode(el));
            document.querySelectorAll('.mobile-permanent-nav .mobile-tab-item').forEach((el) => hideNode(el));
            document.querySelectorAll('a.mobile-tab-item').forEach((el) => hideNode(el));

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

            const hideBottomBars = () => {
              const navKeywordGroups = [
                ['主頁', '分类', '遊戲', '個人中心', '功能'],
                ['主页', '分类', '游戏', '个人中心', '功能'],
                ['home', 'categories', 'games', 'profile', 'function']
              ];

              const hitKeywordGroup = (text) => navKeywordGroups.some((group) => {
                let hit = 0;
                group.forEach((word) => { if (text.includes(word.toLowerCase())) hit += 1; });
                return hit >= 3;
              });

              const bars = Array.from(document.querySelectorAll('nav, div, section, footer'));
              bars.forEach((el) => {
                const style = window.getComputedStyle(el);
                if (!style) return;
                const p = style.position;
                const b = parseInt(style.bottom || '0', 10);
                const w = parseInt(style.width || '0', 10);
                if (!((p === 'fixed' || p === 'sticky') && !Number.isNaN(b) && b <= 96)) return;
                if (Number.isNaN(w) || w < Math.max(260, window.innerWidth * 0.6)) return;

                const text = (el.textContent || '').replace(/\\s+/g, '').toLowerCase();
                const links = el.querySelectorAll('a,button,[role="button"]').length;
                const iconCount = el.querySelectorAll('svg,i,img').length;
                const keywordHit = navWords.some((word) => text.includes(word.toLowerCase()));
                const groupHit = hitKeywordGroup(text);
                const strongBarShape = links >= 4 || iconCount >= 4;
                if (groupHit || (keywordHit && strongBarShape) || (links >= 5 && iconCount >= 3)) {
                  hideNode(el);
                }
              });
            };

            hideBottomBars();

            const topCandidates = Array.from(document.querySelectorAll('header a, header button, nav a, nav button, a, button'));
            topCandidates.forEach((el) => {
              const rect = el.getBoundingClientRect?.();
              if (!rect || rect.top > 140 || rect.width <= 0 || rect.height <= 0) return;
              const text = ((el.textContent || '') + ' ' + (el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '')).toLowerCase();
              const iconText = `${el.id || ''} ${(el.className || '').toString()}`.toLowerCase();
              const looksLikeTopNav = topNavHints.some((word) => text.includes(word) || iconText.includes(word));
              const compactControl = rect.width <= 88 && rect.height <= 88;
              const edgeAligned = rect.left <= 96 || (window.innerWidth - rect.right) <= 96;
              const hasIcon = el.querySelector('svg,i,img') != null;
              if ((isTopFixed(el) || rect.top <= 96) && compactControl && (looksLikeTopNav || (edgeAligned && hasIcon))) {
                hideNode(el);
              }
            });
          };

          const applyPermanentNavHideStyle = () => {
            const id = '__shirayukiHidePermanentNav';
            let style = document.getElementById(id);
            if (!style) {
              style = document.createElement('style');
              style.id = id;
              style.textContent = `
                .mobile-permanent-nav,
                .mobile-permanent-nav *,
                .mobile-tab-item,
                [class*="mobile-permanent-nav"] {
                  display: none !important;
                  visibility: hidden !important;
                  pointer-events: none !important;
                  opacity: 0 !important;
                  height: 0 !important;
                  min-height: 0 !important;
                  max-height: 0 !important;
                }
                header [aria-label*="search" i],
                header [title*="search" i],
                header [aria-label*="back" i],
                header [title*="back" i],
                header [aria-label*="menu" i],
                header [title*="menu" i],
                header [aria-label*="more" i],
                header [title*="more" i],
                [class*="header"] [aria-label*="search" i],
                [class*="header"] [aria-label*="menu" i],
                [class*="header"] [aria-label*="more" i],
                [class*="header"] [title*="search" i],
                [class*="header"] [aria-label*="back" i],
                [class*="header"] [title*="back" i],
                [class*="header"] [title*="menu" i],
                [class*="header"] [title*="more" i],
                [class*="top"] [aria-label*="search" i],
                [class*="top"] [aria-label*="menu" i],
                [class*="top"] [aria-label*="more" i],
                [class*="top"] [title*="search" i],
                [class*="top"] [aria-label*="back" i],
                [class*="top"] [title*="back" i],
                [class*="top"] [title*="menu" i],
                [class*="top"] [title*="more" i],
                [class*="back-button"],
                [class*="search-button"],
                [class*="menu-button"],
                [class*="more-button"],
                [class*="hamburger"],
                [class*="nav-search"],
                [class*="nav-menu"] {
                  display: none !important;
                  visibility: hidden !important;
                  pointer-events: none !important;
                  opacity: 0 !important;
                }
                body {
                  padding-bottom: 0 !important;
                }
              `;
              document.head.appendChild(style);
            }
          };

          window.__shirayukiGoBack = () => {
            const clickBackCandidate = () => {
              const candidates = Array.from(document.querySelectorAll('a, button, [role="button"]'));
              const scored = candidates
                .map((el) => {
                  const rect = el.getBoundingClientRect?.();
                  if (!rect || rect.width <= 0 || rect.height <= 0 || rect.top > 160) return null;
                  const text = ((el.textContent || '') + ' ' + (el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '')).toLowerCase();
                  const meta = `${el.id || ''} ${(el.className || '').toString()}`.toLowerCase();
                  const href = (el.getAttribute?.('href') || '').toLowerCase();
                  const hasBackHint =
                    text.includes('返回') ||
                    text.includes('back') ||
                    text.includes('go back') ||
                    text.includes('上一页') ||
                    meta.includes('back') ||
                    meta.includes('chevron-left') ||
                    meta.includes('arrow-left');
                  if (!hasBackHint) return null;

                  let score = 0;
                  if (rect.left <= 96) score += 4;
                  if (rect.top <= 96) score += 4;
                  if (rect.width <= 88 && rect.height <= 88) score += 2;
                  if (el.querySelector?.('svg,i,img')) score += 2;
                  if (href.startsWith('/')) score += 1;
                  return { el, score };
                })
                .filter(Boolean)
                .sort((a, b) => b.score - a.score);

              const target = scored[0]?.el;
              if (target) {
                target.click();
                return 'dom';
              }
              return null;
            };

            const domResult = clickBackCandidate();
            if (domResult) {
              return domResult;
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

            try {
              if (document.referrer) {
                const referrer = new URL(document.referrer, window.location.origin);
                if (referrer.origin === window.location.origin) {
                  window.location.assign(referrer.pathname + referrer.search + referrer.hash);
                  return 'referrer';
                }
              }
            } catch (e) {}

            const currentPath = pathLower();
            if (currentPath.startsWith('/comic/reader/')) {
              window.location.assign('/');
              return 'fallback-home';
            }
            if (currentPath.startsWith('/comic/')) {
              window.location.assign('/');
              return 'fallback-home';
            }

            return 'none';
          };

          const applyDarkMode = () => {
            const id = '__shirayukiDarkStyle';
            let style = document.getElementById(id);
            if (!window.__shirayukiDarkModeEnabled || isAuthRoute()) {
              if (style) style.remove();
              try {
                document.documentElement.style.removeProperty('background');
                document.documentElement.style.removeProperty('background-color');
                document.body.style.removeProperty('background');
                document.body.style.removeProperty('background-color');
                document.documentElement.style.removeProperty('color');
                document.body.style.removeProperty('color');
              } catch (e) {}
              return;
            }

            if (!style) {
              style = document.createElement('style');
              style.id = id;
              document.head.appendChild(style);
            }

            style.textContent = `
              html, body, #root, #app, #__next, main, .app, .container, .layout, .page, .content, .wrapper {
                background: #0f1117 !important;
                background-color: #0f1117 !important;
                color: #dce3ee !important;
              }
              html, body { margin: 0 !important; min-height: 100vh !important; }
              body, #root, #app, #__next { overflow-x: hidden !important; }
              body *:not(img):not(svg):not(picture):not(canvas):not(video):not(source):not(path):not(use) {
                background: #121621 !important;
                background-color: #121621 !important;
                color: #dce3ee !important;
                border-color: rgba(220, 227, 238, 0.18) !important;
              }
              img, picture, canvas, svg { filter: none !important; }
            `;

            // Extra hard-set for pages that re-hydrate and override class-based styles.
            try {
              document.documentElement.style.setProperty('background', '#0f1117', 'important');
              document.documentElement.style.setProperty('background-color', '#0f1117', 'important');
              document.body.style.setProperty('background', '#0f1117', 'important');
              document.body.style.setProperty('background-color', '#0f1117', 'important');
              document.documentElement.style.setProperty('color', '#dce3ee', 'important');
              document.body.style.setProperty('color', '#dce3ee', 'important');

              // Force-dark top-level containers where SPA routes often rehydrate.
              const roots = [
                document.getElementById('root'),
                document.getElementById('app'),
                document.getElementById('__next'),
                document.querySelector('main'),
                document.querySelector('.app'),
                document.querySelector('.container'),
                document.querySelector('.layout'),
                document.querySelector('.page'),
                document.querySelector('.content'),
                document.querySelector('.wrapper')
              ].filter(Boolean);

              roots.forEach((el) => {
                el.style.setProperty('background', '#0f1117', 'important');
                el.style.setProperty('background-color', '#0f1117', 'important');
                el.style.setProperty('color', '#dce3ee', 'important');
              });

              document.querySelectorAll('body > div, body > main, body > section, body > article, body > nav, body > header, body > footer')
                .forEach((el) => {
                  el.style.setProperty('background', '#0f1117', 'important');
                  el.style.setProperty('background-color', '#0f1117', 'important');
                });
            } catch (e) {}
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

          const pathLower = () => (window.location.pathname || '').toLowerCase();
          const isReaderRoute = () => pathLower().includes('/comic/reader/');
          const isAuthRoute = () => {
            const p = pathLower();
            return p === '/' || p.includes('/login') || p.includes('/register') || p.includes('/signin') || p.includes('/signup');
          };
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
              setTimeout(() => window.__shirayukiApplyNativeTweaks?.(), 0);
              setTimeout(() => window.__shirayukiApplyNativeTweaks?.(), 250);
              return result;
            };
            history.replaceState = function() {
              const result = rawReplace.apply(this, arguments);
              setTimeout(syncPath, 0);
              setTimeout(() => window.__shirayukiApplyNativeTweaks?.(), 0);
              setTimeout(() => window.__shirayukiApplyNativeTweaks?.(), 250);
              return result;
            };
            window.addEventListener('popstate', () => { syncPath(); window.__shirayukiApplyNativeTweaks?.(); });
            window.addEventListener('hashchange', () => { syncPath(); window.__shirayukiApplyNativeTweaks?.(); });
          };

          const installResilienceHooks = () => {
            if (window.__shirayukiResilienceHooked) return;
            window.__shirayukiResilienceHooked = true;

            let scheduled = false;
            const scheduleApply = () => {
              if (scheduled) return;
              scheduled = true;
              setTimeout(() => {
                scheduled = false;
                window.__shirayukiApplyNativeTweaks?.();
              }, 120);
            };

            const observer = new MutationObserver(() => scheduleApply());
            const startObserve = () => {
              if (!document.documentElement) return;
              observer.observe(document.documentElement, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['class', 'style']
              });
            };

            startObserve();
            window.addEventListener('load', scheduleApply);
            window.addEventListener('pageshow', scheduleApply);
            window.addEventListener('focus', scheduleApply);
            window.addEventListener('resize', scheduleApply);
            document.addEventListener('readystatechange', scheduleApply);
            document.addEventListener('visibilitychange', () => {
              if (!document.hidden) scheduleApply();
            });
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

            if (isReaderRoute()) {
              clearShirayukiHiddenNodes();
              removeDarkModeStyle();
              blockVideos();
              return;
            }

            if (isAuthRoute()) {
              removeDarkModeStyle();
              blockVideos();
              return;
            }

            applyPermanentNavHideStyle();
            hideOriginalNav();
            applyDarkMode();
            blockVideos();
          };

          installRouteHooks();
          installResilienceHooks();
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
