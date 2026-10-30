import Foundation
import UIKit
import Combine
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

    init() { cachedStudent = cache.load()?.student }
    var isOnline: Bool { mode == .online && !needsLogin }
    var badge: String { mode == .demo ? "示例数据" : (isOnline ? "已登录" : "离线查看") }

    func refreshCaptcha() async {
        guard !busy else { return }
        busy = true; captchaImage = nil
        defer { busy = false }
        do {
            let challenge = try await client.prepareLogin()
            guard let image = UIImage(data: challenge.image) else { throw CampusError.message("验证码图片无法显示，请重试。") }
            captchaImage = image
        } catch { message = friendly(error) }
    }
    func login(account: String, password: String, captcha: String) async {
        guard !busy else { return }
        busy = true
        do {
            let student = try await client.login(account: account, password: password, captcha: captcha)
            // Never show a previous account's records under a new identity.
            if let cached = cache.load(), cached.student.account == student.account {
                var current = CampusSnapshot(student: student)
                current.timetable = cached.timetable; current.grades = cached.grades; current.exams = cached.exams
                snapshot = current
            } else {
                try cache.clear()
                snapshot = CampusSnapshot(student: student)
            }
            mode = .online; needsLogin = false; captchaImage = nil; cachedStudent = student
            persist()
            busy = false
            await refreshAll()
        } catch {
            message = friendly(error); captchaImage = nil; busy = false
            // Do not silently resubmit a password or show a consumed challenge.
        }
    }
    func refresh(_ feature: Feature, semester: Semester? = nil) async {
        guard !busy else { return }
        guard isOnline else { message = mode == .demo ? "当前展示的是示例数据。退出体验后可登录学校账号。" : "请先重新登录，再获取最新数据。"; return }
        busy = true
        defer { busy = false }
        do {
            switch feature {
            case .timetable: snapshot?.timetable = try await client.fetchTimetable(semester: semester)
            case .grades: snapshot?.grades = try await client.fetchGrades()
            case .exams: snapshot?.exams = try await client.fetchExams(semester: semester)
            }
            persist()
        } catch {
            if (error as? CampusError) == .sessionExpired { needsLogin = true }
            message = "\(feature.rawValue)：\(friendly(error))"
        }
    }
    func refreshAll() async {
        for feature in Feature.allCases {
            guard isOnline else { break }
            await refresh(feature)
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
    func returnToLogin() async {
        guard !busy else { return }
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
            if error.code == .cancelled { return "请求已取消。" }
            return "连接学校服务器失败。请确认网络能够访问教务系统；若学校限制校内访问，请连接校园网或学校提供的 VPN。"
        }
        return error.localizedDescription
    }
}
