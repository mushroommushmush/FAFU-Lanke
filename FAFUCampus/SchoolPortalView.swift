import SwiftUI
import WebKit
import CampusCore

@MainActor private final class PortalModel: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    @Published var error: String?
    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: URL(string: "http://jwgl.fafu.edu.cn/default2.aspx")!))
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.request.url?.absoluteString == "about:blank" || AcademicClient.isAllowed(action.request.url) {
            decisionHandler(.allow)
        } else {
            error = "该链接指向教务系统之外的地址，请使用 Safari 访问学校官网。"
            decisionHandler(.cancel)
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { self.error = "网页加载失败，请检查校园网或学校 VPN 连接。" }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { self.error = error.localizedDescription }
    }
}
private struct PortalWebView: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
@MainActor struct SchoolPortalView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PortalModel()
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("网页需要单独登录；可用于核对原始数据或修改初始密码。")
                    .font(.caption).foregroundStyle(.secondary).padding(12)
                if let error = model.error {
                    Text(error).font(.callout).foregroundStyle(.orange).padding(12)
                }
                PortalWebView(webView: model.webView)
            }
            .navigationTitle("教务原网页").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { model.webView.goBack() } label: { Image(systemName: "chevron.left") }.accessibilityLabel("网页后退")
                    Button { model.error = nil; model.webView.reload() } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("重新加载网页")
                }
            }
        }
    }
}
