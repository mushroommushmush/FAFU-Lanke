import ActivityKit
import CampusCore
import SwiftUI
import Combine

@MainActor final class LessonActivityManager: ObservableObject {
    @Published var message: String?
    private var syncing = false
    func sync(lessons: [Lesson], account: String, enabled: Bool) async {
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        let now = Date()
        let historyKey = "lanke.live.requested." + account + "." + SchoolSchedule.dayKey(now)
        var requested = Set(UserDefaults.standard.stringArray(forKey: historyKey) ?? [])
        // Keep the nearest two activities within the system's limited activity budget.
        let desired = enabled ? Array(lessons.filter { $0.end > now }.sorted { $0.start < $1.start }.prefix(2)) : []
        for activity in Activity<LessonActivity>.activities {
            if activity.attributes.account != account || !desired.contains(where: { $0.id == activity.attributes.lessonID }) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        guard enabled else { UserDefaults.standard.removeObject(forKey: historyKey); message = nil; return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { message = "请在系统设置中允许览课使用实时活动。"; return }
        message = nil
        for lesson in desired {
            let state = LessonActivity.ContentState(name: lesson.name, room: lesson.room, start: lesson.start, end: lesson.end, hasStarted: now >= lesson.start)
            let content = ActivityContent(state: state, staleDate: now < lesson.start ? lesson.start : lesson.end)
            if let activity = Activity<LessonActivity>.activities.first(where: { $0.attributes.lessonID == lesson.id && $0.attributes.account == account }) {
                if activity.content.state.start != state.start || activity.content.state.end != state.end {
                    // A pending activity's scheduled start must follow the edited lesson time.
                    await activity.end(nil, dismissalPolicy: .immediate)
                    requested.remove(lesson.id)
                } else {
                    if activity.content.state != state { await activity.update(content) }
                    continue
                }
            }
            let attributes = LessonActivity(lessonID: lesson.id, account: account)
            // Respect a person's decision to dismiss an activity; do not recreate it every tick.
            guard !requested.contains(lesson.id) else { continue }
            do {
                let notice = lesson.start.addingTimeInterval(-900)
                if notice > now {
                    if #available(iOS 26.0, *) {
                        _ = try Activity.request(attributes: attributes, content: content, pushType: nil,
                            style: .standard, alertConfiguration: AlertConfiguration(title: "即将上课", body: "请查看课程和教室", sound: .default), start: notice)
                        requested.insert(lesson.id)
                    }
                } else {
                    _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
                    requested.insert(lesson.id)
                }
                UserDefaults.standard.set(Array(requested), forKey: historyKey)
            } catch { message = "实时活动暂未启动：\(error.localizedDescription)" }
        }
    }
}

struct ActivityCoordinator: View {
    @EnvironmentObject var store: CampusStore
    @EnvironmentObject var planner: Planner
    @EnvironmentObject var activities: LessonActivityManager
    @Environment(\.scenePhase) private var phase
    @AppStorage("lanke.live.enabled.v2") private var enabled = true
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onReceive(timer) { _ in update() }
            .onChange(of: phase) { _, value in if value == .active { update() } }
            .onChange(of: enabled) { _, _ in update() }
            .onChange(of: store.snapshot?.student.account) { _, account in
                planner.load(account: account ?? "signed-out"); update()
            }
            .onReceive(planner.$saved.dropFirst()) { _ in Task { await Task.yield(); update() } }
            .onAppear { planner.load(account: store.snapshot?.student.account ?? "signed-out"); update() }
    }
    private func update() {
        guard phase == .active else { return }
        let lessons = planner.lessons(store.snapshot?.timetable, on: Date())
        let allowed = enabled && store.mode != .login && store.mode != .demo
        Task { await activities.sync(lessons: lessons, account: store.snapshot?.student.account ?? "", enabled: allowed) }
    }
}
