import SwiftUI
import CampusCore
import Combine

@MainActor final class Planner: ObservableObject {
    struct Saved: Codable {
        var manual: [Lesson] = []
        var hidden: Set<String> = []
        var beginnings: [String: Date] = [:]
        var starts = SchoolSchedule.starts
    }
    @Published var saved = Saved()
    @Published var error: String?
    private var key = ""
    func load(account: String) {
        let next = "lanke.planner." + account
        guard next != key else { return }
        key = next
        if let data = UserDefaults.standard.data(forKey: key) {
            do { saved = try JSONDecoder().decode(Saved.self, from: data) }
            catch { saved = Saved(); self.error = "本机课程设置读取失败，原数据仍保留。" }
        } else { saved = Saved() }
    }
    func persist() {
        guard !key.isEmpty else { return }
        do { UserDefaults.standard.set(try JSONEncoder().encode(saved), forKey: key) }
        catch { self.error = "课程设置保存失败：\(error.localizedDescription)" }
    }
    func clear() { UserDefaults.standard.removeObject(forKey: key); saved = Saved() }
    func beginning(_ report: TimetableReport?) -> Date {
        let semester = report?.options.selected
        let key = semester?.title ?? "当前学期"
        if let date = saved.beginnings[key] { return date }
        // Inferred from the supplied screenshot: Oct 31, 2026 is in week 9.
        return SchoolSchedule.date(2026, 8, 31)
    }
    func lessons(_ report: TimetableReport?, on date: Date) -> [Lesson] {
        let imported = SchoolSchedule.lessons(report: report, on: date, beginning: beginning(report), starts: saved.starts)
        let manual = saved.manual.filter { SchoolSchedule.calendar.isDate($0.start, inSameDayAs: date) }
        return (imported + manual).filter { !saved.hidden.contains($0.id) }.sorted { $0.start < $1.start }
    }
    func add(_ lesson: Lesson) { saved.manual.append(lesson); persist() }
    func remove(_ lesson: Lesson) { saved.hidden.insert(lesson.id); persist() }
}

enum LessonColors {
    static let soon = Color(red: 250/255, green: 192/255, blue: 61/255)
    static let active = Color(red: 192/255, green: 214/255, blue: 150/255)
    static func course(_ name: String) -> Color {
        let colors: [Color] = [.cyan, .orange, .purple, .pink, .mint, .blue, .yellow]
        let hash = name.unicodeScalars.reduce(UInt64(0)) { ($0 &* 31) &+ UInt64($1.value) }
        return colors[Int(hash % UInt64(colors.count))].opacity(0.7)
    }
}

struct ScheduleHome: View {
    @EnvironmentObject var store: CampusStore
    @EnvironmentObject var planner: Planner
    @Environment(\.scenePhase) private var phase
    @AppStorage("lanke.schedule.grid") private var grid = false
    @State private var day = SchoolSchedule.calendar.startOfDay(for: Date())
    @State private var lastToday = SchoolSchedule.dayKey(Date())
    @State private var adding = false
    @State private var selected: Lesson?
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var report: TimetableReport? { store.snapshot?.timetable }
    private var monday: Date { SchoolSchedule.monday(day) }
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    StatusStrip(date: report?.fetchedAt)
                    if store.needsLogin { Button("重新登录以更新数据") { Task { await store.returnToLogin() } } }
                    if let report {
                        SemesterControls(options: report.options, disabled: store.busy || !store.isOnline) { value in
                            Task { await store.refresh(.timetable, semester: value) }
                        }
                    }
                    HStack {
                        Button { moveWeek(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("上一周")
                        Spacer()
                        Text("第\(SchoolSchedule.week(on: day, beginning: planner.beginning(report)))周").font(.headline)
                        Button("今天") { day = SchoolSchedule.calendar.startOfDay(for: Date()) }
                        Spacer()
                        Button { moveWeek(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("下一周")
                    }
                    if grid {
                        weekGrid
                    } else {
                        Picker("星期", selection: Binding(get: {
                            (SchoolSchedule.calendar.component(.weekday, from: day) + 5) % 7
                        }, set: { day = SchoolSchedule.calendar.date(byAdding: .day, value: $0, to: monday)! })) {
                            ForEach(0..<7, id: \.self) { Text(weekdays[$0]).tag($0) }
                        }.pickerStyle(.segmented)
                        Text(day.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(.secondary)
                        TimelineView(.periodic(from: .now, by: 15)) { context in
                            let lessons = planner.lessons(report, on: day)
                            if lessons.isEmpty { EmptyPanel(title: "这一天没有课程", detail: "可点击右上角＋添加课程。") }
                            ForEach(lessons) { lesson in
                                Button { selected = lesson } label: { LessonRow(lesson: lesson, now: context.date) }.buttonStyle(.plain)
                            }
                        }
                    }
                    if let report, !report.adjustments.isEmpty {
                        DisclosureGroup("调停课说明") {
                            Text(report.adjustments).font(.callout).textSelection(.enabled)
                            Text("调停课暂不自动合并。可删除当天原课程，再手动添加调整后的课程。").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let report {
                        DisclosureGroup("学校原始课表") {
                            ForEach(report.courses) { cell in
                                VStack(alignment: .leading) {
                                    Text("周\(weekdays[max(0, min(6, cell.weekday - 1))]) · \(cell.period)").font(.caption)
                                    Text(cell.content).font(.callout).textSelection(.enabled)
                                }.padding(.vertical, 6)
                            }
                        }
                    }
                }.padding(16)
            }
            .background(Palette.background).navigationTitle("我的课表")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("添加课程")
                    Button { Task { await store.refresh(.timetable, semester: report?.options.selected) } }
                    label: { Image(systemName: "arrow.clockwise") }.disabled(store.busy || !store.isOnline).accessibilityLabel("刷新课表")
                }
            }
            .sheet(isPresented: $adding) { AddLessonView(day: day) }
            .sheet(item: $selected) { LessonDetail(lesson: $0) }
            .alert("课程设置", isPresented: Binding(get: { planner.error != nil }, set: { if !$0 { planner.error = nil } })) {
                Button("知道了") { planner.error = nil }
            } message: { Text(planner.error ?? "") }
            .onReceive(ticker) { _ in followToday() }
            .onChange(of: phase) { _, value in if value == .active { followToday() } }
        }
    }
    private func followToday() {
        let today = SchoolSchedule.dayKey(Date())
        if today != lastToday { lastToday = today; day = SchoolSchedule.calendar.startOfDay(for: Date()) }
    }
    private func moveWeek(_ amount: Int) { day = SchoolSchedule.calendar.date(byAdding: .day, value: amount * 7, to: day)! }
    private var weekGrid: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 3) {
                VStack(spacing: 0) {
                    Text("时间").frame(height: 40)
                    ForEach(0..<12, id: \.self) { index in
                        VStack { Text("\(index + 1)"); Text(String(format: "%02d:%02d", planner.saved.starts[index]/60, planner.saved.starts[index]%60)).font(.caption2) }.frame(height: 80)
                    }
                }.frame(width: 42)
                ForEach(0..<7, id: \.self) { index in
                    let date = SchoolSchedule.calendar.date(byAdding: .day, value: index, to: monday)!
                    let courses = planner.lessons(report, on: date)
                    let layout = lanes(for: courses)
                    VStack(spacing: 0) {
                        Text("周\(weekdays[index]) \(SchoolSchedule.calendar.component(.day, from: date))").font(.caption).frame(height: 40)
                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 0) { ForEach(0..<12, id: \.self) { _ in Rectangle().fill(Color.secondary.opacity(0.06)).frame(height: 79).padding(.bottom, 1) } }
                            ForEach(courses) { lesson in
                                TimelineView(.periodic(from: .now, by: 15)) { context in
                                    Button { selected = lesson } label: {
                                        VStack(spacing: 3) {
                                            Text(lesson.name).font(.caption.weight(.semibold))
                                            Text("@" + (lesson.room.isEmpty ? "待确认" : lesson.room)).font(.caption2)
                                        }.foregroundStyle(.black).padding(4).frame(width: 88 / CGFloat(layout.count), height: max(52, position(lesson.end, end: true) - position(lesson.start)))
                                            .background(LessonColors.course(lesson.name), in: RoundedRectangle(cornerRadius: 9))
                                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(lesson.phase(at: context.date) == .soon ? LessonColors.soon : .clear, lineWidth: 4))
                                            .shadow(color: lesson.phase(at: context.date) == .soon ? LessonColors.soon : .clear, radius: 8)
                                    }.buttonStyle(.plain).offset(x: CGFloat(layout.indices[lesson.id] ?? 0) * 88 / CGFloat(layout.count), y: position(lesson.start))
                                }
                            }
                        }.frame(width: 88, height: 960)
                    }
                }
            }
        }
    }
    private func lanes(for courses: [Lesson]) -> (indices: [String: Int], count: Int) {
        var ends: [Date] = []
        var indices: [String: Int] = [:]
        for course in courses.sorted(by: { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }) {
            let lane = ends.firstIndex(where: { $0 <= course.start }) ?? ends.count
            if lane == ends.count { ends.append(course.end) } else { ends[lane] = course.end }
            indices[course.id] = lane
        }
        return (indices, max(1, ends.count))
    }
    private func position(_ date: Date, end: Bool = false) -> CGFloat {
        let parts = SchoolSchedule.calendar.dateComponents([.hour, .minute], from: date)
        let minute = Double(parts.hour! * 60 + parts.minute!)
        let times = planner.saved.starts.map(Double.init)
        for index in 0..<12 {
            if minute <= times[index] + 45 { return CGFloat(Double(index) * 80 + max(0, (minute - times[index]) / 45 * 80)) }
        }
        return 960
    }
}

struct LessonRow: View {
    let lesson: Lesson
    let now: Date
    private var phase: Lesson.Phase { lesson.phase(at: now) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(lesson.name).font(.headline); Spacer(); Text("@" + (lesson.room.isEmpty ? "教室待确认" : lesson.room)).font(.subheadline) }
            Text(status).font(.subheadline).monospacedDigit()
        }.foregroundStyle(.black).padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(phase == .soon ? LessonColors.soon : (phase == .active ? LessonColors.active : .white), in: RoundedRectangle(cornerRadius: 18))
    }
    private var status: String {
        switch phase {
        case .ended: return "已下课"
        case .active: return "距离下课还有 \(Int(ceil(lesson.end.timeIntervalSince(now)/60))) 分钟"
        default: return "\(lesson.start.formatted(date: .omitted, time: .shortened)) 上课 · 还有 \(max(0, Int(ceil(lesson.start.timeIntervalSince(now)/60)))) 分钟"
        }
    }
}

struct AddLessonView: View {
    let day: Date
    @EnvironmentObject var planner: Planner
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var room = ""
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(2700)
    var body: some View {
        NavigationStack {
            Form {
                TextField("课程名称", text: $name)
                TextField("教室（如创211）", text: $room)
                DatePicker("上课", selection: $start)
                DatePicker("下课", selection: $end, in: start...)
            }.navigationTitle("添加课程").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") {
                        planner.add(Lesson(name: name.trimmingCharacters(in: .whitespacesAndNewlines), room: room.trimmingCharacters(in: .whitespacesAndNewlines), start: start, end: end)); dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || end <= start) }
                }
                .onAppear { start = SchoolSchedule.calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!; end = start.addingTimeInterval(2700) }
                .onChange(of: start) { _, value in if end <= value { end = value.addingTimeInterval(2700) } }
        }.environment(\.timeZone, SchoolSchedule.calendar.timeZone)
    }
}

struct LessonDetail: View {
    let lesson: Lesson
    @EnvironmentObject var planner: Planner
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("课程", value: lesson.name)
                LabeledContent("教室", value: lesson.room.isEmpty ? "待确认" : lesson.room)
                LabeledContent("上课", value: lesson.start.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("下课", value: lesson.end.formatted(date: .abbreviated, time: .shortened))
                if !lesson.detail.isEmpty { Text(lesson.detail).textSelection(.enabled) }
                Button("从当日课程表删除", role: .destructive) { confirm = true }
            }.navigationTitle("课程详情").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .confirmationDialog("仅删除本机当天这堂课，不修改学校课表。", isPresented: $confirm, titleVisibility: .visible) {
                    Button("删除当天课程", role: .destructive) { planner.remove(lesson); dismiss() }
                }
        }
    }
}

struct ScheduleSettings: View {
    @EnvironmentObject var activities: LessonActivityManager
    @EnvironmentObject var planner: Planner
    @EnvironmentObject var store: CampusStore
    @AppStorage("lanke.schedule.grid") private var grid = false
    @AppStorage("lanke.live.enabled") private var live = false
    var body: some View {
        Form {
            Section("显示") { Picker("课表模式", selection: $grid) { Text("列表").tag(false); Text("表格").tag(true) }.pickerStyle(.segmented) }
            Section("当前学期校历") {
                DatePicker("第1周周一", selection: Binding(get: { planner.beginning(store.snapshot?.timetable) }, set: {
                    planner.saved.beginnings[store.snapshot?.timetable?.options.selected.title ?? "当前学期"] = SchoolSchedule.monday($0); planner.persist()
                }), displayedComponents: .date)
                Text("默认日期按参考图推算为2026年8月31日；切换学期后请校正。").font(.caption).foregroundStyle(.secondary)
            }
            Section("上课时间 · 每节45分钟") {
                ForEach(0..<12, id: \.self) { index in
                    DatePicker("第\(index + 1)节", selection: Binding(get: {
                        SchoolSchedule.calendar.date(byAdding: .minute, value: planner.saved.starts[index], to: SchoolSchedule.date(2026, 1, 1))!
                    }, set: { value in
                        let p = SchoolSchedule.calendar.dateComponents([.hour, .minute], from: value)
                        let minute = p.hour! * 60 + p.minute!
                        let lower = index == 0 ? 0 : planner.saved.starts[index - 1] + 45
                        let upper = index == 11 ? 1394 : planner.saved.starts[index + 1] - 45
                        planner.saved.starts[index] = min(upper, max(lower, minute)); planner.persist()
                    }), displayedComponents: .hourAndMinute)
                }
            }
            Section("实时活动") {
                Toggle("课程实时活动", isOn: $live)
                if let message = activities.message { Text(message).font(.caption).foregroundStyle(.orange) }
                Text("打开应用后预约当天最近两堂课。课前15分钟启动受系统权限和数量限制影响；强制关闭应用后不能保证准时变色、结束。可点活动中的“结束”，或回到应用自动清理。关闭后重开此开关可重新预约已关闭的活动。").font(.caption).foregroundStyle(.secondary)
            }
            Section { Button("恢复已删除的课程") { planner.saved.hidden = []; planner.persist() } }
        }.navigationTitle("课表设置").navigationBarTitleDisplayMode(.inline)
            .environment(\.timeZone, SchoolSchedule.calendar.timeZone)
    }
}

