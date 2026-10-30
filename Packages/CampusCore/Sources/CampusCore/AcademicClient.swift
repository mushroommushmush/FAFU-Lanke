import Foundation

public struct LoginChallenge: Sendable {
    public let image: Data
}

private final class CampusRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        guard AcademicClient.isAllowed(request.url) else { completionHandler(nil); return }
        completionHandler(request)
    }
}

public actor AcademicClient {
    public static let host = "jwgl.fafu.edu.cn"
    private let redirectDelegate = CampusRedirectDelegate()
    private var session: URLSession?
    private var baseURL: URL?
    private var loginURL: URL?
    private var loginParameters: [String: String]?
    private var student: Student?

    public init() {}
    public nonisolated static func isAllowed(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.host?.lowercased() == host && ["http", "https"].contains(url.scheme?.lowercased() ?? "")
            && url.user == nil && url.password == nil && (url.port == nil || url.port == 80 || url.port == 443)
    }
    private func freshSession() {
        session?.invalidateAndCancel()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = true
        session = URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz12345")
        let token = String((0..<24).map { _ in alphabet.randomElement()! })
        baseURL = URL(string: "http://\(Self.host)/(\(token))/")
        loginURL = nil; loginParameters = nil; student = nil
    }
    public func signOut() {
        session?.invalidateAndCancel(); session = nil
        baseURL = nil; loginURL = nil; loginParameters = nil; student = nil
    }
    private func request(_ url: URL, fields: [String: String]? = nil, referer: URL? = nil) async throws -> (Data, HTTPURLResponse) {
        guard Self.isAllowed(url), let session else { throw CampusError.invalidDestination }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/134.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        if let referer { request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer") }
        if let fields {
            request.httpMethod = "POST"
            request.httpBody = try LegacyEncoding.form(fields)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, Self.isAllowed(response.url) else {
            throw CampusError.invalidDestination
        }
        if (300..<400).contains(response.statusCode) { throw CampusError.invalidDestination }
        if response.statusCode == 401 || response.statusCode == 403 { throw CampusError.sessionExpired }
        guard (200..<300).contains(response.statusCode) else {
            throw CampusError.message("教务系统返回 \(response.statusCode)，请稍后再试。")
        }
        guard data.count < 6_000_000 else { throw CampusError.message("教务系统返回的页面过大。") }
        return (data, response)
    }
    private func html(_ url: URL, fields: [String: String]? = nil, referer: URL? = nil) async throws -> String {
        let result = try await request(url, fields: fields, referer: referer)
        return try LegacyEncoding.decode(result.0, charset: result.1.textEncodingName)
    }
    public func prepareLogin() async throws -> LoginChallenge {
        freshSession()
        guard let baseURL, let initial = URL(string: "default2.aspx", relativeTo: baseURL)?.absoluteURL else {
            throw CampusError.invalidDestination
        }
        let result = try await request(initial)
        let page = try LegacyEncoding.decode(result.0, charset: result.1.textEncodingName)
        if let message = HTMLParser.alertMessage(page) { throw CampusError.message(message) }
        let landedURL = result.1.url ?? initial
        // Honor a server-assigned session path instead of assuming the generated path survived redirects.
        self.baseURL = landedURL.deletingLastPathComponent().appendingPathComponent("")
        let action = try HTMLParser.loginAction(page)
        guard let target = action.isEmpty ? landedURL : URL(string: action, relativeTo: landedURL)?.absoluteURL,
              Self.isAllowed(target) else { throw CampusError.invalidDestination }
        let parameters = try HTMLParser.loginFields(page)
        guard page.range(of: "txtUserName", options: .caseInsensitive) != nil else {
            throw CampusError.unexpectedPage("登录")
        }
        loginURL = target; loginParameters = parameters
        guard let base = self.baseURL, let captcha = URL(string: "CheckCode.aspx", relativeTo: base)?.absoluteURL else {
            throw CampusError.invalidDestination
        }
        let imageResult = try await request(captcha, referer: target)
        guard imageResult.1.mimeType?.hasPrefix("image/") == true else {
            loginParameters = nil
            throw CampusError.message("验证码没有正常返回，请刷新验证码。")
        }
        return LoginChallenge(image: imageResult.0)
    }
    public func login(account: String, password: String, captcha: String) async throws -> Student {
        guard let loginURL, var fields = loginParameters else {
            throw CampusError.message("请先获取验证码。")
        }
        guard !account.isEmpty, !password.isEmpty, !captcha.isEmpty else {
            throw CampusError.message("请填写学号、密码和验证码。")
        }
        for key in ["Textbox1", "Button1", "RadioButtonList1", "lbLanguage", "hidPdrs", "hidsc"] {
            if fields[key] == nil { fields[key] = "" }
        }
        fields["txtUserName"] = account
        fields["TextBox2"] = password
        fields["txtSecretCode"] = captcha
        // A challenge is consumed once. A failed attempt requires a new image/session.
        loginParameters = nil
        let page = try await html(loginURL, fields: fields, referer: loginURL)
        guard let name = try HTMLParser.studentName(page) else {
            throw CampusError.message(HTMLParser.alertMessage(page) ?? "未识别到登录成功页面，学校也未返回可识别的错误提示。这不能确定是密码错误；请在教务原网页核对登录结果。")
        }
        let student = Student(account: account, name: name)
        self.student = student
        return student
    }
    private func pageURL(_ page: String, code: String? = nil) throws -> URL {
        guard let baseURL, let student else { throw CampusError.sessionExpired }
        let query = try "?xh=" + LegacyEncoding.component(student.account)
            + (code == nil ? "" : "&xm=" + LegacyEncoding.component(student.name) + "&gnmkdm=" + code!)
        guard let url = URL(string: page + query, relativeTo: baseURL)?.absoluteURL else {
            throw CampusError.invalidDestination
        }
        return url
    }
    private func semesterPage(_ page: String, code: String, semester: Semester?) async throws -> String {
        let url = try pageURL(page, code: code)
        let referer = try pageURL("xs_main.aspx")
        var pageHTML = try await html(url, referer: referer)
        try HTMLParser.requireAuthenticated(pageHTML)
        guard let semester else { return pageHTML }
        let current = try HTMLParser.options(pageHTML)
        guard current.years.contains(where: { $0.value == semester.year }),
              current.terms.contains(where: { $0.value == semester.term }) else {
            throw CampusError.message("学校页面未提供所选学期，请刷新后重新选择。")
        }
        if current.selected != semester {
            var fields = try HTMLParser.hiddenFields(pageHTML)
            fields["xnd"] = semester.year; fields["xqd"] = semester.term
            pageHTML = try await html(url, fields: fields, referer: referer)
            try HTMLParser.requireAuthenticated(pageHTML)
            guard try HTMLParser.options(pageHTML).selected == semester else {
                throw CampusError.message("教务系统未切换到所选学期，请在原网页核对。")
            }
        }
        return pageHTML
    }
    public func fetchTimetable(semester: Semester? = nil) async throws -> TimetableReport {
        let page = try await semesterPage("xskbcx.aspx", code: "N121602", semester: semester)
        return try HTMLParser.timetable(page)
    }
    public func fetchExams(semester: Semester? = nil) async throws -> RecordsReport {
        let page = try await semesterPage("xskscx.aspx", code: "N121604", semester: semester)
        return try HTMLParser.records(page, page: "考试安排")
    }
    public func fetchGrades() async throws -> RecordsReport {
        let url = try pageURL("xscjcx_dq_fafu.aspx", code: "N121605")
        let first = try await html(url, referer: pageURL("xs_main.aspx"))
        try HTMLParser.requireAuthenticated(first)
        var fields = try HTMLParser.hiddenFields(first)
        fields["ddlxn"] = "全部"; fields["ddlxq"] = "全部"; fields["btnCx"] = ""
        let page = try await html(url, fields: fields, referer: url)
        return try HTMLParser.records(page, page: "成绩")
    }
}
