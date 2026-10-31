import SwiftUI
import WidgetKit
import Combine
import CampusCore

@MainActor final class HomeWidgetPublisher: ObservableObject {
    @Published var status = "等待同步"
    private var previous: HomeWidgetSnapshot?
    private var previousAccount: String?
    private var cleared = false
    func publish(store: CampusStore, planner: Planner) {
        guard let snapshot = store.snapshot, store.mode != .login, store.mode != .demo else {
            if !cleared || previous != nil || previousAccount != nil {
                do { try HomeWidgetCache.clear(); previous = nil; previousAccount = nil; WidgetCenter.shared.reloadTimelines(ofKind: "LankeHomeCourses") }
                catch { status = error.localizedDescription }
                cleared = true
            }
            return
        }
        guard snapshot.timetable != nil || !planner.saved.manual.isEmpty else {
            status = "请先下载课表或添加课程"
            try? HomeWidgetCache.clear()
            WidgetCenter.shared.reloadTimelines(ofKind: "LankeHomeCourses")
            return
        }
        let now = Date()
        if previousAccount != snapshot.student.account {
            do { try HomeWidgetCache.clear() } catch { status = error.localizedDescription; return }
            WidgetCenter.shared.reloadTimelines(ofKind: "LankeHomeCourses")
        }
        let lessons = (0..<7).flatMap { offset -> [HomeWidgetLesson] in
            let day = SchoolSchedule.calendar.date(byAdding: .day, value: offset, to: now)!
            return planner.lessons(snapshot.timetable, on: day).map(HomeWidgetLesson.init)
        }
        let packet = HomeWidgetSnapshot(lessons: Array(lessons.prefix(100)), sourceUpdatedAt: snapshot.timetable?.fetchedAt)
        guard packet != previous || snapshot.student.account != previousAccount else { return }
        do {
            try HomeWidgetCache.write(packet)
            previous = packet; previousAccount = snapshot.student.account
            cleared = false
            status = "已同步课表到主屏幕小组件"
            WidgetCenter.shared.reloadTimelines(ofKind: "LankeHomeCourses")
        } catch { status = error.localizedDescription }
    }
}

struct HomeWidgetCoordinator: View {
    @EnvironmentObject var store: CampusStore
    @EnvironmentObject var planner: Planner
    @EnvironmentObject var publisher: HomeWidgetPublisher
    @Environment(\.scenePhase) private var phase
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onReceive(store.$snapshot) { _ in later() }
            .onReceive(planner.$saved) { _ in later() }
            .onChange(of: phase) { _, value in if value == .active { later() } }
            .onReceive(timer) { _ in if phase == .active { later() } }
            .onAppear { later() }
    }
    private func later() { Task { await Task.yield(); publisher.publish(store: store, planner: planner) } }
}
