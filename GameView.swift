import SwiftUI
import UIKit
import WebKit

// MARK: - 目标站点
/// 只放行 pokebonk.com 及其子域名留在 App 内；其余主框架跳转交给系统浏览器。
enum Site {
    static let startURL = URL(string: "https://pokebonk.com/")!

    static func isAllowed(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "pokebonk.com" || host.hasSuffix(".pokebonk.com")
    }
}

// MARK: - SwiftUI 外壳
struct GameView: View {
    @State private var isLoading = true
    @State private var loadError: String? = nil
    /// 每次 +1 触发一次网页重载（错误页“重新加载”按钮用）
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WebView(
                startURL: Site.startURL,
                reloadToken: reloadToken,
                isLoading: $isLoading,
                loadError: $loadError
            )
            .ignoresSafeArea()

            // 加载中：黑色底上的白色转圈，不遮挡游戏画面
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }

            // 加载失败：简洁错误页 + 重试按钮
            if loadError != nil {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                    Text("无法加载 PokéBonk")
                        .foregroundColor(.white)
                        .font(.headline)
                    Text("请检查网络连接后重试")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Button {
                        loadError = nil
                        isLoading = true
                        reloadToken += 1
                    } label: {
                        Text("重新加载")
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
        }
        .statusBarHidden(true)
    }
}

// MARK: - WKWebView 包装
struct WebView: UIViewRepresentable {
    let startURL: URL
    let reloadToken: Int
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadError: $loadError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // —— 游戏/网页兼容配置 ——
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.allowsInlineMediaPlayback = true          // 允许视频/游戏画面内联播放
        config.mediaPlaybackRequiresUserAction = false   // 允许自动播放音频/视频
        config.applicationNameForMediaPlayback = "PokéBonk"
        config.websiteDataStore = .default()

        // 注入一段小脚本：长按不弹菜单、禁止误选文字，让游戏手感更像原生 App
        let gameFeelScript = WKUserScript(
            source: """
            document.documentElement.style.webkitTouchCallout = 'none';
            document.documentElement.style.userSelect = 'none';
            document.documentElement.style.webkitUserSelect = 'none';
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(gameFeelScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        // 不顶到刘海/Home Indicator 的 safe area  inset，不允许橡皮筋滚动条
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        // 游戏里横滑容易误触发“前进/后退”手势，关掉
        webView.allowsBackForwardNavigationGestures = false

        webView.load(URLRequest(url: startURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // reloadToken 变化 = 用户点了“重新加载”
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            webView.reload()
        }
    }

    // MARK: Coordinator
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding var isLoading: Bool
        @Binding var loadError: String?
        var lastReloadToken: Int = 0

        init(isLoading: Binding<Bool>, loadError: Binding<String?>) {
            _isLoading = isLoading
            _loadError = loadError
        }

        // MARK: 导航策略
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            // about:blank / 站内资源与同域跳转一律放行
            if url.isFileURL || url.scheme == "about" || Site.isAllowed(url) {
                decisionHandler(.allow)
                return
            }
            // 仅“主框架”跳转到外部站点时交给 Safari，避免广告 iframe 把用户带出 App
            if navigationAction.targetFrame?.isMainFrame == true {
                UIApplication.shared.open(url, options: [:])
            }
            decisionHandler(.cancel)
        }

        // MARK: 弹窗 / window.open / target=_blank
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            // 不另开新窗口：新请求直接在当前 WebView 里打开，避免游戏弹窗被吞掉
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        // MARK: 加载状态
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // 程序主动取消的导航不算错误
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                isLoading = false
                loadError = error.localizedDescription
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code != NSURLErrorCancelled {
                isLoading = false
                loadError = error.localizedDescription
            }
        }

        // WebContent 进程被系统杀掉（内存压力）后自动刷新一次
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }
    }
}
