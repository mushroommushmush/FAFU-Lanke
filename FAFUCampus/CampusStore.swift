import Foundation
import UIKit
import Combine
import Vision
import CampusCore

@MainActor final class CampusStore: ObservableObject {
    enum Mode: Equatable { case login, online, offline, demo }
    enum Feature: String, CaseIterable { case timetable = "课表", grades = "成绩", exams = "考试" }
    @Published var mode: Mode = .login
    @Published var snapshot: CampusSnapshot?
    @Published var busy = false
    @Published var message: String?
    @Published var captchaImage: UIImage?
    @Published var cachedStudent: Student?
    @Published var needsLogin = false
    private let client = AcademicClient()
    private let cache = CacheStore()

    private let vault = SessionVault()
    private let credentials = CredentialsVault()
    @Published var rememberLogin = UserDefaults.standard.bool(forKey: "lanke.rememberLogin")
    var rememberedCredentials: LoginCredentials? { credentials.load() }
    func setRememberLogin(_ enabled: Bool) {
        rememberLogin = enabled
        UserDefaults.standard.set(enabled, forKey: "lanke.rememberLogin")
        if !enabled { credentials.clear() }
    }
    private func automaticLogin() async throws {
        guard rememberLogin, let value = credentials.load() else { throw CampusError.sessionExpired }
        var succeeded = false
        defer { if !succeeded { needsLogin = true } }
        let challenge = try await client.prepareLogin()
        let recognized = await Task.detached { () -> String? in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            do {
                try VNImageRequestHandler(data: challenge.image).perform([request])
                let text = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined() ?? ""
                let code = text.filter { $0.isASCII && $0.isLetter || $0.isNumber }
                return code.count == 4 ? code : nil
            } catch { return nil }
        }.value
        guard let recognized else {
            captchaImage = UIImage(data: challenge.image)
            throw CampusError.message("验证码需要手动输入，请返回登录页完成登录。")
        }
        let student = try await client.login(account: value.account, password: value.password, captcha: recognized)
        guard snapshot == nil || snapshot?.student.account == student.account else { throw CampusError.sessionExpired }
        if snapshot == nil { snapshot = CampusSnapshot(student: student) }
        mode = .online; needsLogin = false
        try await saveSession(); succeeded = true
    }
    func authenticatedPortalSession() async -> SavedSession? {
        guard mode != .demo else { return nil }
        if !busy {
            busy = true
            defer { busy = false }
            do {
                if let saved = try vault.load() { try await client.restore(saved) }
                do { _ = try await client.validateSession() }
                catch CampusError.sessionExpired { try await automaticLogin() }
                try await saveSession()
            } catch { /* The original portal remains available for manual authentication. */ }
        }
        return await portalSession()
    }
    func portalSession() async -> SavedSession? {
        guard mode != .demo else { return nil }
        return await client.savedSession() ?? (try? vault.load())
    }
    func acceptPortalSession(_ saved: SavedSession) async {
        guard !busy, mode != .demo,
            snapshot == nil || snapshot?.student.account == saved.student.account else { return }
        busy = true; defer { busy = false }
        // Validate in a separate client before replacing the app's current identity/session.
        let candidate = AcademicClient()
        do {
            try await candidate.restore(saved)
            _ = try await candidate.validateSession()
            try await client.restore(saved)
            if snapshot == nil { snapshot = CampusSnapshot(student: saved.student) }
            cachedStudent = saved.student; mode = .online; needsLogin = false
            try await saveSession(); persist()
        } catch { /* A login page or expired browser session must not replace a valid native session. */ }
    }
    func refreshElectives() async {
        guard !busy, isOnline else { return }
        busy = true; defer { busy = false }
        do {
            do { snapshot?.electives = try await client.fetchElectives() }
            catch CampusError.sessionExpired {
                try await automaticLogin()
                snapshot?.electives = try await client.fetchElectives()
            }
            try await saveSession(); persist()
        } catch { message = friendly(error) }
    }
    private var didRestore = false
    @Published var restoring = false
    @Published var hasSavedSession = false

    init() {
        let cached = cache.load()
        cachedStudent = cached?.student
        if let saved = try? vault.load() {
            hasSavedSession = true; restoring = true
            snapshot = cached?.student.account == saved.student.account ? cached : CampusSnapshot(student: saved.student)
            mode = .offline
        }
    }
    func restoreOnLaunch() async {
        guard !didRestore else { return }
        didRestore = true
        await restoreConnection()
    }
    func restoreConnection() async {
        guard !busy else { return }
        busy = true; restoring = true
        defer { busy = false; restoring = false }
        do {
            guard let saved = try vault.load() else {
                if rememberLogin { try await automaticLogin() }; return
            }
            hasSavedSession = true
            try await client.restore(saved)
            do { _ = try await client.validateSession() }
            catch CampusError.sessionExpired { try await automaticLogin() }
            if snapshot?.student.account != saved.student.account { snapshot = CampusSnapshot(student: saved.student) }
            mode = .online; needsLogin = false
            do { try await saveSession() }
            catch { message = "登录已恢复，但保存会话失败：\(friendly(error))" }
        } catch {
            mode = snapshot == nil ? .login : .offline
            if (error as? CampusError) == .sessionExpired || (error as? CampusError) == .invalidDestination {
                needsLogin = true
                do { try vault.clear(); hasSavedSession = false }
                catch { message = friendly(error) }
                if message == nil { message = "学校登录已失效，请重新登录。已下载的数据仍可查看。" }
            } else {
                message = "暂时无法恢复连接：\(friendly(error))"
            }
        }
    }
    private func saveSession() async throws {
        if let saved = await client.savedSession() {
            try vault.save(saved); hasSavedSession = true
        }
    }
    func saveSessionOnBackground() async {
        guard mode == .online, !needsLogin, !busy else { return }
        do { try await saveSession() } catch { message = friendly(error) }
    }
    var isOnline: Bool { mode == .online && !needsLogin }
    var badge: String { restoring ? "正在恢复登录…" : (mode == .demo ? "示例数据" : (isOnline ? "已登录" : "离线查看")) }

    func refreshCaptcha() async {
        guard !busy else { return }
        busy = true; captchaImage = nil
        defer { busy = false }
        do {
            let challenge = try await client.prepareLogin()
            guard let image = UIImage(data: challenge.image) else { throw CampusError.message("验证码图片无法显示，请重试。") }
            captchaImage = image
        } catch { message = "获取登录页或验证码失败：\(friendly(error))" }
    }
    func login(account: String, password: String, captcha: String) async {
        guard !busy else { return }
        busy = true
        do {
            let student = try await client.login(account: account, password: password, captcha: captcha)
            // Never show a previous account's records under a new identity.
            if let cached = cache.load(), cached.student.account == student.account {
                var current = CampusSnapshot(student: student)
                current.timetable = cached.timetable; current.grades = cached.grades; current.exams = cached.exams; current.electives = cached.electives
                snapshot = current
            } else {
                try cache.clear()
                snapshot = CampusSnapshot(student: student)
            }
            mode = .online; needsLogin = false; captchaImage = nil; cachedStudent = student
            if rememberLogin {
                do { try credentials.save(LoginCredentials(account: account, password: password)) }
                catch { message = friendly(error) }
            } else { credentials.clear() }
            persist()
            do { try await saveSession() }
            catch { message = "已登录，但未能保存登录状态：\(friendly(error))" }
            busy = false
            await refreshAll()
        } catch {
            message = "登录阶段失败：\(friendly(error))"; captchaImage = nil; busy = false
            // Do not silently resubmit a password or show a consumed challenge.
        }
    }
    private func fetch(_ feature: Feature, semester: Semester? = nil) async throws {
        switch feature {
        case .timetable: snapshot?.timetable = try await client.fetchTimetable(semester: semester)
        case .grades: snapshot?.grades = try await client.fetchGrades()
        case .exams: snapshot?.exams = try await client.fetchExams(semester: semester)
        }
    }
    func refresh(_ feature: Feature, semester: Semester? = nil) async {
        guard !busy else { return }
        guard isOnline else { message = mode == .demo ? "当前展示的是示例数据。退出体验后可登录学校账号。" : "请先重新登录，再获取最新数据。"; return }
        busy = true
        defer { busy = false }
        do {
            do { try await fetch(feature, semester: semester) }
            catch CampusError.sessionExpired {
                try await automaticLogin()
                try await fetch(feature, semester: semester)
            }
            try await saveSession()
            persist()
        } catch {
            if (error as? CampusError) == .sessionExpired { needsLogin = true }
            message = "\(feature.rawValue)查询失败：\(friendly(error))"
        }
    }
    func refreshAll() async {
        guard !busy, isOnline else { return }
        busy = true
        defer { busy = false }
        var failures: [String] = []
        for feature in Feature.allCases {
            guard isOnline else { break }
            do {
                do { try await fetch(feature) }
                catch CampusError.sessionExpired { try await automaticLogin(); try await fetch(feature) }
            }
            catch {
                if (error as? CampusError) == .sessionExpired { needsLogin = true }
                failures.append("\(feature.rawValue)：\(friendly(error))")
            }
        }
        do {
            if !needsLogin { try await saveSession() }
            if let snapshot { try cache.save(snapshot) }
        }
        catch { failures.append("保存到本机失败：\(error.localizedDescription)") }
        if !failures.isEmpty {
            message = "登录已完成，但部分数据未能获取：\n" + failures.joined(separator: "\n")
        }
    }
    func openOffline() {
        guard !busy, let cached = cache.load() else { return }
        snapshot = cached; mode = .offline; needsLogin = true
    }
    func openDemo() {
        guard !busy else { return }
        snapshot = DemoData.snapshot; mode = .demo; needsLogin = false
    }
    func requestLogin() async {
        guard !busy else { return }
        await client.signOut()
        snapshot = nil; mode = .login; needsLogin = false; captchaImage = nil
    }
    func returnToLogin() async {
        guard !busy else { return }
        do { try vault.clear() } catch { message = friendly(error); return }
        hasSavedSession = false
        credentials.clear(); setRememberLogin(false)
        await PortalModel.clearWebsite()
        await client.signOut()
        snapshot = nil; mode = .login; captchaImage = nil; needsLogin = false
        cachedStudent = cache.load()?.student
    }
    func clearAndSignOut() async {
        guard !busy else { return }
        do {
            try cache.clear()
            await returnToLogin()
            cachedStudent = nil
        } catch { message = "清除本地数据失败：\(error.localizedDescription)" }
    }
    private func persist() {
        guard mode != .demo, let snapshot else { return }
        do { try cache.save(snapshot) }
        catch { message = "数据已获取，但未能保存到本机：\(error.localizedDescription)" }
    }
    private func friendly(_ error: Error) -> String {
        if let error = error as? URLError {
            let detail: String
            switch error.code {
            case .cancelled: detail = "请求已取消，请重新获取验证码。"
            case .timedOut: detail = "连接学校服务器超时。请在同一设备的 Safari 中测试教务网站。"
            case .notConnectedToInternet: detail = "设备未联网，或未允许本应用使用网络。"
            case .cannotFindHost, .dnsLookupFailed: detail = "无法解析教务网站域名。"
            case .cannotConnectToHost: detail = "无法连接教务服务器。请确认当前网络能访问学校教务网站。"
            case .networkConnectionLost: detail = "与教务服务器的连接中断，请重试。"
            case .appTransportSecurityRequiresSecureConnection: detail = "系统阻止了当前网址的 HTTP 请求，需要检查应用网络配置。"
            case .secureConnectionFailed, .serverCertificateUntrusted,
                 .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid: detail = "学校网站的安全连接或证书校验失败。"
            default: detail = "连接学校服务器失败，请在同一设备的 Safari 中核对是否能访问。"
            }
            return detail + "（网络错误码：\(error.code.rawValue)）"
        }
        return error.localizedDescription
    }
}
