import SwiftUI
import WidgetKit
import CampusCore

struct CourseWidgetEntry: TimelineEntry {
    let date: Date
    let packet: HomeWidgetSnapshot?
    var problem: String? = nil
}

struct CoursesProvider: TimelineProvider {
    func placeholder(in context: Context) -> CourseWidgetEntry { sample() }
    func getSnapshot(in context: Context, completion: @escaping (CourseWidgetEntry) -> Void) {
        completion(context.isPreview ? sample() : load())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CourseWidgetEntry>) -> Void) {
        let entry = load()
        let dates = entry.packet?.timelineDates(after: entry.date) ?? [entry.date]
        let entries = dates.map { date in
            if let packet = entry.packet, !packet.covers(date) {
                return CourseWidgetEntry(date: date, packet: nil, problem: "课表缓存已过期，请打开览课同步")
            }
            return CourseWidgetEntry(date: date, packet: entry.packet, problem: entry.problem)
        }
        completion(Timeline(entries: entries, policy: .after(entry.date.addingTimeInterval(6 * 3600))))
    }
    private func load() -> CourseWidgetEntry {
        do {
            let now = Date()
            let packet = try HomeWidgetCache.read()
            if let packet, !packet.covers(now) { return CourseWidgetEntry(date: now, packet: nil, problem: "课表缓存已过期，请打开览课同步") }
            return CourseWidgetEntry(date: now, packet: packet)
        }
        catch { return CourseWidgetEntry(date: Date(), packet: nil, problem: "请打开览课检查小组件同步") }
    }
    func sample() -> CourseWidgetEntry {
        let today = SchoolSchedule.calendar.startOfDay(for: Date())
        let now = today.addingTimeInterval(7 * 3600 + 50 * 60)
        let packet = HomeWidgetSnapshot(lessons: [
            HomeWidgetLesson(id: "1", name: "计量经济学", room: "诚A601", start: today.addingTimeInterval(8*3600), end: today.addingTimeInterval(9*3600+35*60)),
            HomeWidgetLesson(id: "2", name: "国际金融学", room: "田410", start: today.addingTimeInterval(9*3600+55*60), end: today.addingTimeInterval(11*3600+30*60)),
            HomeWidgetLesson(id: "3", name: "农村金融学", room: "禧401", start: today.addingTimeInterval(14*3600), end: today.addingTimeInterval(15*3600+35*60))
        ], sourceUpdatedAt: now)
        return CourseWidgetEntry(date: now, packet: packet)
    }
}

struct HomeCoursesView: View {
    let entry: CourseWidgetEntry
    var previewFamily: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var family
    private let forest = Color(red: 0.12, green: 0.34, blue: 0.25)
    private let yellow = Color(red: 250/255, green: 192/255, blue: 61/255)
    private let green = Color(red: 192/255, green: 214/255, blue: 150/255)
    private var next: HomeWidgetLesson? { entry.packet?.next(at: entry.date) }
    private var today: [HomeWidgetLesson] { entry.packet?.today(at: entry.date) ?? [] }
    private var rows: [HomeWidgetLesson] {
        let upcoming = today.filter { $0.end > entry.date }
        return Array((upcoming.isEmpty ? today.suffix(3).map { $0 } : upcoming).prefix(3))
    }
    private func clock(_ date: Date) -> String {
        let c = SchoolSchedule.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour!, c.minute!)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("览课", systemImage: "leaf.fill").font(.caption.weight(.semibold)).foregroundStyle(forest)
                Spacer(minLength: 4)
                Text(entry.date.formatted(.dateTime.month().day())).font(.caption2).foregroundStyle(.secondary)
            }
            if entry.packet == nil {
                Spacer(minLength: 0)
                Text("课表在这里").font(.headline)
                Text(entry.problem ?? "打开览课，登录后同步课表").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else if (previewFamily ?? family) == .systemSmall {
                small
            } else {
                medium
            }
        }
        .containerBackground(for: .widget) { Color(uiColor: .secondarySystemGroupedBackground) }
        .widgetURL(URL(string: "lanke://timetable"))
    }
    @ViewBuilder private var small: some View {
        if let lesson = next {
            let active = entry.date >= lesson.start
            HStack(spacing: 4) {
                Circle().fill(active ? green : yellow).frame(width: 6, height: 6)
                Text(active ? "正在上课" : "下一节课").font(.caption2).foregroundStyle(.secondary)
            }
            Text(lesson.name).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
            Text("@" + (lesson.room.isEmpty ? "教室待确认" : lesson.room)).font(.caption).foregroundStyle(forest).lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Text(active ? "距下课 " : "距上课 ").font(.caption2).foregroundStyle(.secondary)
                Text(timerInterval: (active ? lesson.start : entry.date)...(active ? lesson.end : lesson.start), countsDown: true, showsHours: false)
                    .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(forest)
            }
        } else {
            Spacer(minLength: 0)
            Image(systemName: "cup.and.saucer").foregroundStyle(forest)
            Text(today.isEmpty ? "今天没有课程" : "今日课程已结束").font(.headline)
            Text("点此打开完整课表").font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日").font(.title3.bold())
                Text("\(today.count) 堂课").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(next == nil && !today.isEmpty ? "已结束" : "从容上课").font(.caption2).foregroundStyle(forest)
            }.frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                if rows.isEmpty {
                    Text("今天没有课程").font(.headline)
                    Text("点此查看完整课表").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(rows) { lesson in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(entry.date >= lesson.end ? Color.secondary.opacity(0.25) : (entry.date >= lesson.start ? green : yellow)).frame(width: 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lesson.name).font(.caption.weight(.semibold)).lineLimit(1)
                            Text("@" + (lesson.room.isEmpty ? "教室待确认" : lesson.room)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 1)
                        Text(clock(lesson.start)).font(.caption2.monospacedDigit()).foregroundStyle(forest)
                    }.frame(maxHeight: 34)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxHeight: .infinity, alignment: .top)
    }
}

struct HomeCoursesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LankeHomeCourses", provider: CoursesProvider()) { entry in HomeCoursesView(entry: entry) }
            .configurationDisplayName("今日课表与下一节课")
            .description("查看当天课程、教室与下一节课倒计时。")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HomeWidgetDesignPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("主屏幕小组件 · 设计预览").font(.title2.bold())
                Text("使用示例课程数据").font(.caption).foregroundStyle(.secondary)
                HomeCoursesView(entry: CoursesProvider().sample(), previewFamily: .systemSmall)
                    .padding(16).frame(width: 170, height: 170).background(.background, in: RoundedRectangle(cornerRadius: 24))
                HomeCoursesView(entry: CoursesProvider().sample(), previewFamily: .systemMedium)
                    .padding(16).frame(maxWidth: 360).frame(height: 170).background(.background, in: RoundedRectangle(cornerRadius: 24))
            }.padding(20)
        }.background(Color(uiColor: .systemGroupedBackground))
    }
}
