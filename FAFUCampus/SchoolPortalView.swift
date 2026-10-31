import SwiftUI
import WebKit
import CampusCore

@MainActor final class PortalModel: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    @Published var error: String?
    private var prepared = false
    private weak var store: CampusStore?
    static func clearWebsite() async {
        let data = WKWebsiteDataStore.default()
        let records = await data.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        await data.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records)
        UserDefaults.standard.removeObject(forKey: "lanke.portal.owner")
        UserDefaults.standard.removeObject(forKey: "lanke.portal.url")
    }
    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true

    }
    func prepare(store: CampusStore) async {
        guard !prepared else { return }
        prepared = true; self.store = store
        let saved = await store.authenticatedPortalSession()
        let owner = saved?.student.account ?? "guest"
        if UserDefaults.standard.string(forKey: "lanke.portal.owner") != owner { await Self.clearWebsite() }
        UserDefaults.standard.set(owner, forKey: "lanke.portal.owner")
        var target = URL(string: "http://jwgl.fafu.edu.cn/default2.aspx")!
        if let saved, saved.isValid {
            // Replace cookies rather than mixing native and browser sessions.
            for cookie in await webView.configuration.websiteDataStore.httpCookieStore.allCookies() {
                await webView.configuration.websiteDataStore.httpCookieStore.deleteCookie(cookie)
            }
            for cookie in saved.cookies.compactMap({ $0.httpCookie }) {
                await webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            }
            let client = AcademicClient()
            if (try? await client.restore(saved)) != nil, let url = try? await client.portalURL() { target = url }
        }
        webView.load(URLRequest(url: target))
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url, AcademicClient.isAllowed(url) else { return }
        Task {
            guard let store else { return }
            let old = await store.portalSession()
            let account = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "xh" })?.value ?? old?.student.account
            guard let account, !account.isEmpty,
                  old == nil || account == old?.student.account else { return }
            let raw = try? await webView.evaluateJavaScript("document.getElementById('xhxm')?.textContent || ''")
            let name = (raw as? String ?? "").replacingOccurrences(of: "同学", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            let saved = SavedSession(baseURL: url.deletingLastPathComponent().appendingPathComponent(""),
                student: Student(account: account, name: name), cookies: cookies.filter { $0.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")) == AcademicClient.host }.map(SessionCookie.init))
            await store.acceptPortalSession(saved)
            UserDefaults.standard.set(account, forKey: "lanke.portal.owner")
        }
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
    @EnvironmentObject private var store: CampusStore
    @StateObject private var model = PortalModel()
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("自动复用当前登录状态；学校会话失效时可在此重新登录。")
                    .font(.caption).foregroundStyle(.secondary).padding(12)
                if let error = model.error {
                    Text(error).font(.callout).foregroundStyle(.orange).padding(12)
                }
                PortalWebView(webView: model.webView)
            }
            .task { await model.prepare(store: store) }
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
